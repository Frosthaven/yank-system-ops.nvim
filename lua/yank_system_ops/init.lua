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

--- Download a URI into the target directory
-- @param uri string URL or FTP link
-- @param target_dir string Directory to save the file
-- @return boolean success
--- Download a URI into the target directory with proper extension detection
-- @param uri string URL or FTP link
-- @param target_dir string Directory to save the file
-- @return string|nil Path to downloaded file, or nil on failure
local function __download_uri(uri, target_dir)
    if not uri or uri == "" then
        vim.notify("No URI provided to download", vim.log.levels.WARN, { title = "yank-system-ops" })
        return nil
    end

    local filename = uri:match(".+/([^/]+)$") or "downloaded_file"
    filename = filename:gsub("%?.*$", ""):gsub("#.*$", "")

    -- If filename has no extension, try to detect from headers or content
    local ext = filename:match("%.([^.]+)$")
    if not ext then
        -- Try Content-Type header
        local mime
        if vim.fn.executable("curl") == 1 then
            mime = vim.fn.system(string.format('curl -sI "%s" | grep -i Content-Type | awk \'{print $2}\' | tr -d "\r"', uri))
        elseif vim.fn.executable("wget") == 1 then
            mime = vim.fn.system(string.format('wget --spider --server-response "%s" 2>&1 | grep -i Content-Type | awk \'{print $2}\' | tr -d "\r"', uri))
        end
        mime = vim.trim(mime or "")

        local mime_map = {
            ["image/png"] = "png",
            ["image/jpeg"] = "jpg",
            ["image/jpg"] = "jpg",
            ["image/gif"] = "gif",
            ["image/webp"] = "webp",
            ["application/zip"] = "zip",
            ["application/pdf"] = "pdf",
        }

        ext = mime_map[mime]
        if not ext then
            -- Fallback: fetch first bytes and detect via magic numbers
            local tmpfile = vim.fn.tempname()
            local cmd
            if vim.fn.executable("curl") == 1 then
                cmd = string.format('curl -sL -o "%s" "%s"', tmpfile, uri)
            elseif vim.fn.executable("wget") == 1 then
                cmd = string.format('wget -q -O "%s" "%s"', tmpfile, uri)
            else
                vim.notify("Neither curl nor wget is available", vim.log.levels.ERROR, { title = "yank-system-ops" })
                return nil
            end
            vim.fn.system(cmd)

            local f = io.open(tmpfile, "rb")
            if f then
                local bytes = f:read(8) or ""
                f:close()
                local hex = bytes:gsub('.', function(c) return string.format('%02X', c:byte()) end)
                local magic_map = {
                    ["89504E470D0A1A0A"] = "png",
                    ["FFD8FF"] = "jpg",
                    ["47494638"] = "gif",
                    ["504B0304"] = "zip",
                    ["25504446"] = "pdf",
                    ["52494646"] = "webp",
                }
                for sig, mx_ext in pairs(magic_map) do
                    if hex:find(sig, 1, true) then
                        ext = mx_ext
                        break
                    end
                end
                os.remove(tmpfile)
            end
        end
    end

    if not ext then ext = "bin" end
    if not filename:match("%." .. ext .. "$") then
        filename = filename .. "." .. ext
    end

    local final_path = target_dir .. "/" .. filename
    local download_cmd
    if vim.fn.executable("curl") == 1 then
        download_cmd = string.format('curl -fL -A "Mozilla/5.0" -o "%s" "%s"', final_path, uri)
    elseif vim.fn.executable("wget") == 1 then
        download_cmd = string.format('wget -O "%s" "%s"', final_path, uri)
    else
        vim.notify("Neither curl nor wget is available to download the URI", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    local result = vim.fn.system(download_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Download failed:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    return final_path
end

--- Paste/put files from system clipboard into current buffer directory
-- Supports local files, URLs, or images from clipboard
-- @return nil
function M.put_files_from_clipboard()
    local ctx_items, target_dir = __get_buffer_context()
    target_dir = target_dir or vim.fn.getcwd() -- ensure it's a string

    if not target_dir or vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return
    end

    local clip = vim.fn.getreg("+") or ""
    clip = vim.trim(clip)

    if clip == "" then
        vim.notify("Clipboard is empty", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    -- Is it a URL we can curl/wget?
    local is_url = clip:match("^https?://") or clip:match("^ftp://")
    if is_url then
        local ok = __download_uri(clip, target_dir)
        if ok then
            __refresh_buffer_view()
            vim.notify("URL downloaded successfully into: " .. target_dir, vim.log.levels.INFO, { title = "yank-system-ops" })
        else
            vim.notify("Failed to download URL", vim.log.levels.ERROR, { title = "yank-system-ops" })
        end
        return
    end

    -- Is it image data?
    if os_module.clipboard_has_image and os_module:clipboard_has_image() then
        local img_path = os_module:save_clipboard_image(target_dir)
        if img_path then
            __refresh_buffer_view()
            vim.notify(
                "Image saved from clipboard: " .. img_path,
                vim.log.levels.INFO,
                { title = "yank-system-ops" }
            )
            return
        end
    end

    -- Treat as local file paths
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

--- Recursively extract an archive into a target directory
-- Handles nested archives like .tar.gz, .tgz, .tar.bz2, .tar.xz
-- @param archive_path string Full path to archive
-- @param target_dir string Directory to extract into
-- @return boolean success
local function __extract_archive_recursive(archive_path, target_dir)
    if vim.fn.filereadable(archive_path) == 0 then
        vim.notify("Archive not found: " .. archive_path, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Record files before extraction
    local before = vim.fn.glob(target_dir .. "/*", false, true)

    -- Extract with 7z
    local cmd = string.format('7z x -y "%s" -o"%s"', archive_path, target_dir)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Extraction failed:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Record files after extraction
    local after = vim.fn.glob(target_dir .. "/*", false, true)

    -- Determine new files created by this extraction
    local new_files = {}
    local before_set = {}
    for _, f in ipairs(before) do before_set[f] = true end
    for _, f in ipairs(after) do
        if not before_set[f] then table.insert(new_files, f) end
    end

    -- Recursively extract any new .tar files
    for _, f in ipairs(new_files) do
        if f:match("%.tar$") then
            local ok = __extract_archive_recursive(f, target_dir)
            os.remove(f)  -- remove intermediate .tar
            if not ok then return false end
        end
    end

    return true
end

--- Extract an archive from clipboard into the current buffer directory
-- Supports nested archives like .tar.gz, .tar.bz2, .tgz, etc.
function M.extract_files_from_clipboard()
    local _, target_dir = __get_buffer_context()
    local clip = vim.fn.getreg("+") or ""

    -- Normalize clipboard path (handle file:// URIs and trim)
    clip = vim.trim(clip):gsub("^file://", "")
    clip = vim.fn.fnamemodify(clip, ":p")

    -- Attempt download if URL (optional helper can go here)
    -- clip = maybe_download_url(clip, target_dir) 

    -- Ensure file exists
    if clip == "" or vim.fn.filereadable(clip) == 0 then
        vim.notify("Clipboard does not contain a valid archive file", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    -- Validate extension
    local ext = clip:match("%.([^.]+)$")
    if not ext or not ext:match("zip") and not ext:match("tar") and not ext:match("gz")
        and not ext:match("bz2") and not ext:match("xz") and not ext:match("7z") and not ext:match("rar") then
        vim.notify("Clipboard file is not a recognized archive type", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    -- Recursively extract archives
    local ok = __extract_archive_recursive(clip, target_dir)
    if ok then
        __refresh_buffer_view()
        vim.notify("Archive extracted successfully into: " .. target_dir, vim.log.levels.INFO, { title = "yank-system-ops" })
    end
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
