-- Yank System Ops ------------------------------------------------------------
-------------------------------------------------------------------------------

--- Yank System Ops
-- Core functionality for yank-system-ops.nvim
-- @module yank_system_ops
local M = {}

--- Default configuration
-- @table config
-- @field storage_path string Path to store compressed files
-- @field files_to_keep number Number of compressed files to retain
-- @field debug boolean Enable debug notifications
M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}

--- Internal flag to prevent multiple setup calls
-- @boolean
M._loaded = false

--- Setup yank-system-ops
-- Initializes module and applies configuration
-- @param opts table Optional configuration overrides
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

--- OS name detected by vim
-- @string
local os_name = vim.loop.os_uname().sysname

--- OS-specific module (Darwin/Linux/Windows)
-- @table os_module
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

-- Include Buffer Specific Module ---------------------------------------------
-------------------------------------------------------------------------------

--- Load buffer module for a given buffer
-- Safely loads filetype-specific module, fallback to base module
-- @param bufnr number Optional buffer handle
-- @return table Buffer module
local function get_buffer_module(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype or ""

    local ok, mod = pcall(require, "yank_system_ops.buffer_module." .. ft)
    if not ok or type(mod) ~= "table" then
        mod = require("yank_system_ops.buffer_module.__base")
    end

    return mod
end

-- Flash Highlight Helper -----------------------------------------------------
-------------------------------------------------------------------------------

--- Namespace used for flash highlights
-- @number
local ns = vim.api.nvim_create_namespace 'yank_system_ops_yank_flash'

--- Flash-highlight lines in a buffer
-- @param bufnr number Buffer handle
-- @param start_line number Start line (0-indexed)
-- @param end_line number End line (0-indexed)
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

-- Yank Functions -------------------------------------------------------------
-------------------------------------------------------------------------------

--- Yank GitHub URL for selected lines
-- @return nil
function M.yank_github_url()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    local repo_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if repo_root == '' or vim.fn.isdirectory(repo_root) == 0 then
        vim.notify('Not inside a Git repository', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    local branch = vim.fn.systemlist('git rev-parse --abbrev-ref HEAD')[1]
    if branch == '' or branch == 'HEAD' then
        vim.notify('Could not determine Git branch', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    local remote_url = vim.fn.systemlist('git config --get remote.origin.url')[1]
    if not remote_url or remote_url == '' then
        vim.notify('No Git remote found', vim.log.levels.WARN, { title = 'yank-system-ops' })
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
        vim.notify('Cannot copy GitHub URL: file has ' .. table.concat(msg_parts, '/') .. '!', vim.log.levels.WARN, { title = 'yank-system-ops' })
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

    vim.notify('Yanked GitHub URL', vim.log.levels.INFO, { title = 'yank-system-ops' })
end

--- Yank diagnostics in selection as a markdown code block
-- @return nil
function M.yank_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.mode()
    local start_line, end_line

    if mode:match '[vV]' then
        start_line = vim.fn.getpos('v')[2] - 1
        end_line = vim.fn.getpos('.')[2] - 1
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
    else
        start_line = vim.api.nvim_win_get_cursor(0)[1] - 1
        end_line = start_line
    end

    local all_diags = vim.diagnostic.get(bufnr)
    local selected_diags = {}
    for _, diag in ipairs(all_diags) do
        local d_start = diag.lnum
        local d_end = diag.end_lnum or diag.lnum
        if d_end >= start_line and d_start <= end_line then
            table.insert(selected_diags, diag)
        end
    end

    local messages = {}
    if vim.tbl_isempty(selected_diags) then
        table.insert(messages, 'No Diagnostic Warnings Found')
    else
        for _, diag in ipairs(selected_diags) do
            local line_num = diag.lnum + 1
            table.insert(messages, string.format('`%d`: %s', line_num, diag.message))
            table.insert(messages, '')
        end
    end

    local code_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

    -- Ensure all lines are strings and valid text
    for _, line in ipairs(code_lines) do
        if type(line) ~= 'string' then
            vim.notify('Cannot yank: selection contains non-text content', vim.log.levels.WARN, { title = 'yank-system-ops' })
            return
        end
    end

    local filename = vim.api.nvim_buf_get_name(bufnr)
    local relpath = vim.fn.fnamemodify(filename, ':.')
    local line_info = relpath .. ':' .. (start_line + 1)
    if end_line > start_line then
        line_info = line_info .. '-' .. (end_line + 1)
    end

    local ext = filename:match '^.+%.(.+)$' or ''
    local lang_map = {
        ts = 'ts', tsx = 'ts', js = 'js', jsx = 'js',
        lua = 'lua', php = 'php', rs = 'rs',
    }
    local lang = lang_map[ext] or ext or ''

    local code_text = table.concat(code_lines, '\n')
    local out = string.format('Diagnostic:\n\n%s\n\n`%s`:\n```%s\n%s\n```', table.concat(messages, '\n'), line_info, lang, code_text)

    local ok, _ = pcall(vim.fn.setreg, '+', out)
    if not ok then
        vim.notify('Cannot yank: selection contains non-text content', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    M.flash_highlight(bufnr, start_line, end_line)
    vim.notify('Yanked diagnostic code block', vim.log.levels.INFO, { title = 'yank-system-ops', render = 'compact' })
end

--- Yank selected lines as markdown code block
-- @return nil
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

    -- Ensure all lines are strings and valid text
    for _, line in ipairs(lines) do
        if type(line) ~= 'string' then
            vim.notify('Cannot yank: selection contains non-text content', vim.log.levels.WARN, { title = 'yank-system-ops' })
            return
        end
    end

    local filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'txt'
    local out = string.format('```%s\n%s\n```', filetype, table.concat(lines, '\n'))

    local ok, _ = pcall(vim.fn.setreg, '+', out)
    if not ok then
        vim.notify('Cannot yank: selection contains non-text content', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    M.flash_highlight(bufnr, start_line - 1, end_line - 1)
    vim.notify('Yanked code block', vim.log.levels.INFO, { title = 'yank-system-ops' })
end

--- Refresh explorers and buffers after extraction
-- @param bufnr number Optional buffer handle
local function __refresh_buffer_view(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local mod = get_buffer_module(bufnr)
    mod.refresh_view()

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

-- Yank compressed file functions ---------------------------------------------

--- Get available 7z binary
-- @return string|nil Returns binary name or nil if not found
function __get_7zip_binary()
    local possible_binaries = { '7z', '7zz' }
    for _, b in ipairs(possible_binaries) do
        if vim.fn.executable(b) == 1 then
            return b
        end
    end

    vim.notify('No 7z binary found in PATH (tried: ' .. table.concat(possible_binaries, ', ') .. ')', vim.log.levels.ERROR, { title = 'yank-system-ops' })
    return nil
end

--- Get buffer context using buffer modules
-- @param bufnr number Optional buffer handle
-- @return table items List of full file paths
-- @return string base_dir Active directory for buffer
-- @return string filetype Filetype of buffer
local function __get_buffer_context(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local mod = get_buffer_module(bufnr)
    local items = mod.get_files() or {}
    local base_dir = mod.get_active_dir() or vim.fn.getcwd()
    local ft = vim.bo[bufnr].filetype

    return items, base_dir, ft
end

--- Compress files into a zip archive
-- @param items table List of file paths
-- @param base_dir string Base directory
-- @param filetype string Filetype context
-- @return string|nil Path to zip file
local function __create_zip(items, base_dir, filetype)
    if not items or #items == 0 then
        vim.notify('No files/folders to compress', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    local project_root = vim.fn.finddir('.git/..', base_dir .. ';')
    local project_prefix = ''
    if project_root ~= '' and type(project_root) == 'string' then
        project_prefix = vim.fn.fnamemodify(project_root, ':t') .. '__'
    end

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

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local zip_name = string.format('%s%s__%s.nvim.zip', project_prefix, base_name, timestamp)

    local downloads = M.config.storage_path
    if vim.fn.isdirectory(downloads) == 0 then
        vim.fn.mkdir(downloads, 'p')
    end
    local zip_path = downloads .. '/' .. zip_name

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
        vim.notify('Failed to create zip: ' .. result, vim.log.levels.ERROR, { title = 'yank-system-ops' })
        return
    end

    vim.fn.setreg('+', zip_path)

    local existing = vim.fn.globpath(downloads, '*.nvim.zip', true, true)
    table.sort(existing, function(a, b)
        return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
    end)
    for i = (M.config.files_to_keep + 1), #existing do
        os.remove(existing[i])
    end

    return zip_path
end

--- Copy selected files to system clipboard
-- @return nil
function M.yank_files_to_clipboard()
    local items, _ = __get_buffer_context()
    if not items or #items == 0 then
        vim.notify("No files selected to yank", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    local ok, err = pcall(os_module.add_files_to_clipboard, items)
    if not ok then
        vim.notify("Failed to copy files to clipboard: " .. tostring(err), vim.log.levels.ERROR, { title = "yank-system-ops" })
        return
    end

    vim.notify("Files copied to system clipboard", vim.log.levels.INFO, { title = "yank-system-ops" })
end


--- Paste/put files from system clipboard into current buffer directory
-- @return nil
function M.put_files_from_clipboard()
    local _, target_dir = __get_buffer_context()
    if not target_dir or vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return
    end

    local success = os_module.put_files_from_clipboard(target_dir)
    if success then
        __refresh_buffer_view()
        vim.notify("Clipboard files put successfully", vim.log.levels.INFO, { title = "yank-system-ops" })
    else
        vim.notify("No valid files found in clipboard", vim.log.levels.WARN, { title = "yank-system-ops" })
    end
end


--- Compress selected files into a .nvim.zip and copy to clipboard
-- @return nil
function M.zip_files_to_clipboard()
    local items, base_dir, filetype = __get_buffer_context()
    if not items or #items == 0 then
        vim.notify("No files selected to compress", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    local zip_path, err = __create_zip(items, base_dir, filetype)
    if not zip_path then
        vim.notify("Compression failed: " .. tostring(err), vim.log.levels.ERROR, { title = "yank-system-ops" })
        return
    end

    os_module.add_files_to_clipboard(zip_path)
    vim.notify("Compressed archive added to clipboard", vim.log.levels.INFO, { title = "yank-system-ops" })
end


--- Extract an archive from clipboard into the current buffer directory
-- Supports: .zip, .tar, .tar.gz, .tgz, .7z, .rar, and others supported by 7z
-- @return nil
function M.extract_files_from_clipboard()
    local _, target_dir = __get_buffer_context()
    local clip = vim.fn.getreg("+") or ""

    -- Normalize clipboard path (handle file:// URIs and trim)
    clip = vim.trim(clip):gsub("^file://", "")
    clip = vim.fn.fnamemodify(clip, ":p")

    -- Ensure file exists
    if clip == "" or vim.fn.filereadable(clip) == 0 then
        vim.notify("Clipboard does not contain a valid archive file", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    -- Validate extension (basic heuristic)
    local ext = clip:match("%.([^.]+)$")
    if not ext or not ext:match("zip") and not ext:match("tar") and not ext:match("gz")
        and not ext:match("bz2") and not ext:match("xz") and not ext:match("7z") and not ext:match("rar") then
        vim.notify("Clipboard file is not a recognized archive type", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    -- Extract using 7z (handles most formats)
    local cmd = string.format('7z x -y "%s" -o"%s"', clip, target_dir)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Extraction failed:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return
    end

    __refresh_buffer_view()
    vim.notify("Archive extracted successfully into: " .. target_dir, vim.log.levels.INFO, { title = "yank-system-ops" })
end

--- Yank relative path of current file
-- @return nil
function M.yank_relative_path()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    local relpath = vim.fn.fnamemodify(filename, ':.' .. cwd)

    vim.fn.setreg('+', relpath)
    vim.notify('Yanked relative path', vim.log.levels.INFO, { title = 'yank-system-ops' })
end

--- Yank absolute path of current file
-- @return nil
function M.yank_absolute_path()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    vim.fn.setreg('+', filename)
    vim.notify('Yanked absolute path', vim.log.levels.INFO, { title = 'yank-system-ops' })
end

-- Explorer Functions ---------------------------------------------------------
-------------------------------------------------------------------------------

--- Open file manager at current buffer's file or directory
-- @return nil
function M.open_buffer_in_file_manager()
    local items, base_dir, _ = __get_buffer_context()

    local target
    if #items == 1 then
        target = items[1]
    elseif #items > 1 then
        target = base_dir
    else
        target = base_dir
    end

    if not target or vim.fn.empty(target) == 1 then
        vim.notify('No file or directory found', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return
    end

    local file_path = vim.fn.fnamemodify(target, ':p')
    os_module.open_file_browser(file_path)
end

return M
