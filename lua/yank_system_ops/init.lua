-- Yank System Ops ------------------------------------------------------------
-------------------------------------------------------------------------------

local M = {}

M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}

M._loaded = false

function M.setup(opts)
    if M._loaded then
        vim.notify('yank-system-ops is already loaded!', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end
    M._loaded = true

    opts = opts or {}
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})

    -- ensure storage path ends in a slash
    if not M.config.storage_path:match '/$' then
        M.config.storage_path = M.config.storage_path .. '/'
    end

    if M.config.debug then
        vim.notify('Setup with config:\n' .. vim.inspect(M.config), vim.log.levels.DEBUG, { title = 'yank-system-ops' })
    end
end

-- Include OS Specific Module -------------------------------------------------
-------------------------------------------------------------------------------

local os_name = vim.loop.os_uname().sysname
local os_module_ok, os_module = pcall(
    require,
    "yank_system_ops.os_module." .. os_name
)
if not os_module_ok then
    vim.notify(
        "yank-system-ops: Unsupported OS: " .. os_name, vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
    return
end

-- Flash Highlight Helper -----------------------------------------------------
-------------------------------------------------------------------------------

local ns = vim.api.nvim_create_namespace 'yank_system_ops_yank_flash'

-- this function highlights lines from start_line to end_line (0-indexed) in the
-- given buffer for a short duration
function M.flash_highlight(bufnr, start_line, end_line)
    local hl_group = 'IncSearch'
    local duration = 200 -- ms

    for l = start_line, end_line do
        vim.api.nvim_buf_set_extmark(bufnr, ns, l, 0, {
            end_line = l + 1,
            hl_group = hl_group,
            hl_eol = true,
        })
    end

    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, ns, start_line, end_line + 1)
    end, duration)
end


-- OS-Specific ----------------------------------------------------------------
-------------------------------------------------------------------------------

local os_functions = {}

os_functions.add_files_to_clipboard = {}
function os_functions.add_files_to_clipboard.Darwin (files)
    -- handle single file by wrapping in array
    if type(files) == 'string' then
        files = { files }
    end

    local osa_files = {}
    for _, f in ipairs(files) do
        table.insert(osa_files, 'POSIX file "' .. f .. '"')
    end

    local osa_cmd = 'osascript -e \'set the clipboard to {' .. table.concat(osa_files, ', ') .. '}\''
    local result = vim.fn.system(osa_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to copy file to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

function os_functions.add_files_to_clipboard.Linux(files)
    -- Handle single file input
    if type(files) == 'string' then
        files = { files }
    end

    -- Build URI list
    local uri_list = {}
    for _, f in ipairs(files) do
        local abs_path = vim.fn.fnamemodify(f, ':p')
        table.insert(uri_list, 'file://' .. abs_path)
    end

    -- Join URIs and escape quotes for shell safety
    local uris_str = table.concat(uri_list, '\n'):gsub('"', '\\"')

    local cmd
    if vim.fn.executable('wl-copy') == 1 then
        -- Wayland
        cmd = string.format([[bash -c 'printf "%%s" "%s" | wl-copy -t text/uri-list']], uris_str)
    elseif vim.fn.executable('xclip') == 1 then
        -- X11
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xclip -selection clipboard -t text/uri-list']], uris_str)
    elseif vim.fn.executable('xsel') == 1 then
        -- Fallback: plain text only
        vim.notify('xsel does not support text/uri-list — copying as plain text instead', vim.log.levels.WARN, { title = 'Keymap' })
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xsel --clipboard --input']], uris_str)
    else
        vim.notify('No supported clipboard utility found (wl-copy, xclip, xsel)', vim.log.levels.WARN, { title = 'Keymap' })
        return false
    end

    -- Run the command
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to copy file(s) to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end

    return true
end

function os_functions.add_files_to_clipboard.Windows_NT (files)
    -- handle single file by wrapping in array
    if type(files) == 'string' then
        files = { files }
    end

    local ps_files = {}
    for _, f in ipairs(files) do
        table.insert(ps_files, '\'' .. f .. '\'')
    end

    local ps_cmd = 'powershell -Command "[System.Windows.Forms.Clipboard]::SetFileDropList((New-Object System.Collections.Specialized.StringCollection; ' .. table.concat(ps_files, '; $_.Add(') .. ')))"'
    local result = vim.fn.system(ps_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to copy file to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

-- Yank Functions -------------------------------------------------------------
-------------------------------------------------------------------------------

-- Yanks the selected line(s) as a GitHub URL to the clipboard. If the user
-- has unsaved changes or unpushed commits, it will not yank the URL and will
-- notify the user instead.
function M.yank_github_url()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    local repo_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if repo_root == '' or vim.fn.isdirectory(repo_root) == 0 then
        vim.notify('Not inside a Git repository', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    local branch = vim.fn.systemlist('git rev-parse --abbrev-ref HEAD')[1]
    if branch == '' or branch == 'HEAD' then
        vim.notify('Could not determine Git branch', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    local remote_url = vim.fn.systemlist('git config --get remote.origin.url')[1]
    if not remote_url or remote_url == '' then
        vim.notify('No Git remote found', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    if remote_url:match '^git@' then
        remote_url = remote_url:gsub(':', '/')
        remote_url = remote_url:gsub('git@', 'https://')
    end
    remote_url = remote_url:gsub('%.git$', '')

    local relpath = vim.fn.fnamemodify(filename, ':.' .. repo_root)

    local mode = vim.fn.mode()
    local start_line, end_line
    if mode:match '[vV]' then
        start_line = vim.fn.getpos('v')[2]
        end_line = vim.fn.getpos('.')[2]
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
    else
        start_line = vim.api.nvim_win_get_cursor(0)[1]
        end_line = start_line
    end

    local unpushed = vim.fn.systemlist(string.format('git log %s --not --remotes -- %s', branch, vim.fn.shellescape(relpath)))
    local status = vim.fn.systemlist(string.format('git status --porcelain %s', vim.fn.shellescape(relpath)))

    if #unpushed > 0 or #status > 0 then
        local msg_parts = {}
        if #unpushed > 0 then
            table.insert(msg_parts, 'unpushed commits')
        end
        if #status > 0 then
            table.insert(msg_parts, 'uncommitted changes')
        end
        vim.notify('Cannot copy GitHub URL: file has ' .. table.concat(msg_parts, '/') .. '!', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    local url = string.format('%s/blob/%s/%s', remote_url, branch, relpath)
    url = url .. '?t=' .. os.time()

    if start_line == end_line then
        url = url .. '#L' .. start_line
    else
        url = url .. '#L' .. start_line .. '-L' .. end_line
    end

    vim.fn.setreg('+', url)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
    M.flash_highlight(bufnr, start_line - 1, end_line - 1)

    vim.notify('Yanked GitHub URL', vim.log.levels.INFO, { title = 'Keymap' })
end

-- Yanks the selected line(s) and collects any diagnostics (errors, warnings,
-- etc.) in those lines. After formatting into markdown code blocks, it copies
-- the result to the clipboard.
function M.yank_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.mode()
    local start_line, end_line

    if mode:match '[vV]' then
        -- Visual mode: use selection
        start_line = vim.fn.getpos('v')[2] - 1
        end_line = vim.fn.getpos('.')[2] - 1
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
    else
        -- Normal mode: current line only
        start_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        end_line = start_line
    end

    -- Collect all diagnostics in buffer
    local all_diags = vim.diagnostic.get(bufnr)
    local selected_diags = {}
    for _, diag in ipairs(all_diags) do
        local d_start = diag.lnum
        local d_end = diag.end_lnum or diag.lnum
        -- Include any diagnostic that overlaps selection
        if d_end >= start_line and d_start <= end_line then
            table.insert(selected_diags, diag)
        end
    end

    -- Combine diagnostic messages with line numbers
    local messages = {}
    if vim.tbl_isempty(selected_diags) then
        table.insert(messages, 'No Diagnostic Warnings Found')
    else
        for _, diag in ipairs(selected_diags) do
            local line_num = diag.lnum + 1 -- convert 0-index to 1-index
            table.insert(messages, string.format('`%d`: %s', line_num, diag.message))
            table.insert(messages, '') -- blank line between diagnostics
        end
    end
    local all_messages = table.concat(messages, '\n')

    -- Get relative file path + line range
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local relpath = vim.fn.fnamemodify(filename, ':.') -- relative path
    local line_info = relpath .. ':' .. (start_line + 1)
    if end_line > start_line then
        line_info = line_info .. '-' .. (end_line + 1)
    end

    -- Detect language from extension
    local ext = filename:match '^.+%.(.+)$' or ''
    local lang_map = {
        ts = 'ts',
        tsx = 'ts',
        js = 'js',
        jsx = 'js',
        lua = 'lua',
        php = 'php',
        rs = 'rs',
    }
    local lang = lang_map[ext] or ext or ''

    -- Collect code lines without soft wrap
    local code_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
    local code_text = table.concat(code_lines, '\n')

    -- Build final string
    local out = string.format('Diagnostic:\n\n%s\n\n`%s`:\n```%s\n%s\n```', all_messages, line_info, lang, code_text)

    -- clipboard copy
    vim.fn.setreg('+', out)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
    M.flash_highlight(bufnr, start_line, end_line)

    -- Notify user
    vim.notify('Yanked diagnostic code block', vim.log.levels.INFO, { title = 'Keymap', render = 'compact' })
end

-- Yanks the selected line(s) and formats them into a markdown code block,
-- copying the result to the clipboard.
function M.yank_codeblock()
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.mode()
    local start_line, end_line

    if mode:match '[vV]' then
        start_line = vim.fn.getpos('v')[2]
        end_line = vim.fn.getpos('.')[2]
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
    else
        start_line = vim.api.nvim_win_get_cursor(0)[1]
        end_line = start_line
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    local filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'txt'
    local out = string.format('```%s\n%s\n```', filetype, table.concat(lines, '\n'))

    vim.fn.setreg('+', out)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
    M.flash_highlight(bufnr, start_line - 1, end_line - 1)

    vim.notify('Yanked code block', vim.log.levels.INFO, { title = 'Keymap' })
end

-- Yank compressed file functions ---------------------------------------------

function __get_7zip_binary()
    local possible_binaries = { '7z', '7zz' }
    for _, b in ipairs(possible_binaries) do
        if vim.fn.executable(b) == 1 then
            return b
        end
    end

    vim.notify('No 7z binary found in PATH (tried: ' .. table.concat(possible_binaries, ', ') .. ')', vim.log.levels.ERROR, { title = 'Keymap' })
    return nil
end

-- mode = "compress" | "extract"
-- returns items, base_dir, filetype
local function __get_buffer_context(mode)
    local items = {}
    local base_dir
    local filetype = vim.bo.filetype

    if filetype == 'minifiles' then
        local curr_path = vim.fn.expand '%:p'
        if curr_path ~= '' then
            curr_path = curr_path:gsub('^minifiles://%d+//', '/')
            local stat = vim.loop.fs_stat(curr_path)
            if stat then
                if stat.type == 'directory' then
                    base_dir = curr_path
                else
                    base_dir = vim.fn.fnamemodify(curr_path, ':h')
                    if mode == 'compress' then
                        table.insert(items, curr_path)
                    end
                end
            end
        end
        if not base_dir then
            base_dir = vim.fn.getcwd()
        end
    elseif filetype == 'netrw' then
        base_dir = vim.b.netrw_curdir or vim.fn.getcwd()
    else
        local curr_file = vim.fn.expand '%:p'
        if curr_file ~= '' then
            base_dir = vim.fn.fnamemodify(curr_file, ':h')
            if mode == 'compress' then
                table.insert(items, curr_file)
            end
        else
            base_dir = vim.fn.getcwd()
        end
    end

    -- If compressing and no explicit items, scan base_dir
    if mode == 'compress' and vim.tbl_isempty(items) and base_dir then
        local scan = vim.fn.globpath(base_dir, '*', true, true)
        for _, f in ipairs(scan) do
            if vim.loop.fs_stat(f) then
                table.insert(items, f)
            end
        end
    end

    return items, base_dir, filetype
end

local function __compress_file(items, base_dir, filetype)
    if not items or #items == 0 then
        vim.notify('No files/folders to compress', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    -- Determine project root for prefix
    local project_root = vim.fn.finddir('.git/..', base_dir .. ';')
    local project_prefix = ''

    -- Only compute prefix if we found a project root
    if project_root ~= '' and type(project_root) == 'string' then
        project_prefix = vim.fn.fnamemodify(project_root, ':t') .. '__'
    end

    -- Determine base name
    local first_item = items[1]
    local base_name
    if filetype == 'minifiles' or filetype == 'netrw' then
        base_name = vim.fn.fnamemodify(base_dir:gsub('/$', ''), ':t')
    else
        base_name = vim.fn.fnamemodify(first_item:gsub('/$', ''), ':t')
    end
    if base_name == '' then
        base_name = 'project'
    end

    -- Add timestamp
    local timestamp = os.date '%Y%m%d_%H%M%S'
    local zip_name = string.format('%s%s__%s.nvim.zip', project_prefix, base_name, timestamp)

    -- Downloads dir
    local downloads = M.config.storage_path
    if vim.fn.isdirectory(downloads) == 0 then
        vim.fn.mkdir(downloads, 'p')
    end
    local zip_path = downloads .. '/' .. zip_name

    -- Build 7z args
    local rel_items = {}
    for _, f in ipairs(items) do
        local st = vim.loop.fs_stat(f)
        if st then
            table.insert(rel_items, string.format('"%s"', f))
        end
    end

    local binary = __get_7zip_binary()
    local cmd = string.format('%s a -tzip "%s" %s -r', binary, zip_path, table.concat(rel_items, ' '))
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to create zip: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return
    end

    -- Yank zip path
    vim.fn.setreg('+', zip_path)

    -- Keep latest files only
    local existing = vim.fn.globpath(downloads, '*.nvim.zip', true, true)
    table.sort(existing, function(a, b)
        return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
    end)
    for i = (M.config.files_to_keep + 1), #existing do
        os.remove(existing[i])
    end

    return zip_path
end

-- Extract a zip archive into target_dir, return file_count or error
local function __extract_zip(zip_path, target_dir)
    local binary = __get_7zip_binary()

    -- Count files
    local list_cmd = string.format('%s l -ba "%s"', binary, zip_path)
    local zip_list = vim.fn.split(vim.fn.system(list_cmd), '\n')
    local file_count = 0
    for _, f in ipairs(zip_list) do
        if f ~= '' then
            file_count = file_count + 1
        end
    end

    -- Extract with overwrite
    local extract_cmd = string.format('%s x "%s" -o"%s" -aoa', binary, zip_path, target_dir)
    local result = vim.fn.system(extract_cmd)
    if vim.v.shell_error ~= 0 then
        return nil, 'Failed to extract zip: ' .. result
    end

    return file_count
end

-- Refresh explorers and buffers after extraction
local function __refresh_after_extract(filetype)
    if filetype == 'minifiles' then
        require('mini.files').open()
    elseif filetype == 'netrw' then
        vim.cmd 'Explore'
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name ~= '' and vim.fn.filereadable(buf_name) == 1 then
            if vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd 'checktime'
                end)
            end
        end
    end
end

function M.yank_compressed_file()
    local items, base_dir, filetype = __get_buffer_context 'compress'
    if not base_dir or #items == 0 then
        return
    end

    local zip_path = __compress_file(items, base_dir, filetype)
    if not zip_path then
        vim.notify('Failed to create zip file', vim.log.levels.ERROR, { title = 'Keymap' })
        return
    end

    local zip_name = vim.fn.fnamemodify(zip_path, ':t') -- tail of the path
    vim.notify(string.format('%s\n  Yanked path', zip_name), vim.log.levels.INFO, { title = 'Keymap' })
end

-- puts the entire binary content of the compressed file into the clipboard
-- for pasting into other applications that accept binary data
function M.yank_file_sharing()
    local items, base_dir, filetype = __get_buffer_context 'compress'
    if not base_dir or #items == 0 then
        return
    end

    local target_path

    if #items == 1 then
        -- Single file: copy it directly
        target_path = items[1]
        if vim.fn.filereadable(target_path) == 0 then
            vim.notify('File does not exist: ' .. target_path, vim.log.levels.ERROR, { title = 'Keymap' })
            return
        end
    else
        -- Multiple files/folders: compress first
        target_path = __compress_file(items, base_dir, filetype)
        if not target_path or vim.fn.filereadable(target_path) == 0 then
            return
        end
    end

    -- Copy the file (or zip) as a "real file" to clipboard
    os_module.add_files_to_clipboard(target_path)
end

function M.extract_compressed_file()
    local zip_path = vim.fn.getreg '+'
    if zip_path == '' then
        vim.notify('Clipboard is empty', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end
    if not zip_path:match '%.nvim%.zip$' then
        vim.notify('Clipboard does not contain a .nvim.zip file', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    local _, target_dir, filetype = __get_buffer_context 'extract'
    if not target_dir or vim.fn.isdirectory(target_dir) == 0 then
        vim.notify('Target directory not found', vim.log.levels.ERROR, { title = 'Keymap' })
        return
    end

    local file_count, err = __extract_zip(zip_path, target_dir)
    if not file_count then
        vim.notify(err or 'Unknown error extracting zip', vim.log.levels.ERROR, { title = 'Keymap' })
        return
    end

    __refresh_after_extract(filetype)

    vim.notify(string.format('%s\n  Extracted %d file(s)', zip_path:match '([^/]+)$', file_count), vim.log.levels.INFO, { title = 'Keymap' })
end

-- Yanks the relative path of the current file to the clipboard
function M.yank_relative_path()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    local relpath = vim.fn.fnamemodify(filename, ':.' .. cwd)

    vim.fn.setreg('+', relpath)

    vim.notify('Yanked relative path', vim.log.levels.INFO, { title = 'Keymap' })
end

-- Yanks the absolute path of the current file to the clipboard
function M.yank_absolute_path()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    vim.fn.setreg('+', filename)

    vim.notify('Yanked absolute path', vim.log.levels.INFO, { title = 'Keymap' })
end

-- Explorer Functions ---------------------------------------------------------
-------------------------------------------------------------------------------

-- Opens the file manager at the current buffer's file or directory
function M.open_buffer_in_file_manager()
    local items, base_dir, _ = __get_buffer_context 'compress'

    local target
    if #items == 1 then
        target = items[1] -- Single file
    elseif #items > 1 then
        target = base_dir -- Multiple files: just open base_dir
    else
        target = base_dir -- Fallback
    end

    if not target or vim.fn.empty(target) == 1 then
        vim.notify('No file or directory found', vim.log.levels.WARN, { title = 'Keymap' })
        return
    end

    local file_path = vim.fn.fnamemodify(target, ':p')
    os_module.open_file_browser(file_path)
end

return M
