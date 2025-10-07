--- Archive handling for yank-system-ops
-- Compress files, manage old archives, and handle clipboard operations
-- @module yank_system_ops.archive
local M = {}

local loader = require 'yank_system_ops.__loader'
local ui = require 'yank_system_ops.ui'
local pathinfo = require 'yank_system_ops.pathinfo'

local os_module = loader.get_os_module()
local config = loader.get_config()

--- Normalize a path to absolute form with forward slashes
function M.normalize_path(p)
    local abs = vim.fn.fnamemodify(p, ':p')
    return abs:gsub('\\', '/')
end

--- Get available 7z binary
function M.get_7zip_binary()
    local possible_binaries = { '7z', '7zz' }

    if vim.fn.has 'win32' == 1 then
        -- On Windows, assume '7z' works in PowerShell
        -- common installations use an app execution alias that vim
        -- can't detect with vim.fn.executable
        return '7z'
    else
        for _, b in ipairs(possible_binaries) do
            if vim.fn.executable(b) == 1 then
                return b
            end
        end
        vim.notify(
            'No 7z binary found in PATH (tried: '
                .. table.concat(possible_binaries, ', ')
                .. ')',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end
end

--- Compress files into a zip archive
-- @param items table|string List of file paths
-- @param base_dir string Base directory
-- @param filetype string Filetype context
-- @return string|nil Path to zip file
function M.create_zip(items, base_dir, filetype)
    -- Ensure items is always a table of strings
    local filtered = pathinfo.filter_recursive_items(items)
    if not filtered then
        items = {}
    elseif type(filtered) == 'string' then
        items = { filtered }
    elseif type(filtered) == 'table' then
        items = filtered
    else
        items = {}
    end

    if #items == 0 then
        vim.notify(
            'No files/folders to compress',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    base_dir = M.normalize_path(base_dir)
    if base_dir:sub(-1) ~= '/' then
        base_dir = base_dir .. '/'
    end

    -- Ensure project_root is a string
    local project_root = vim.fn.finddir('.git/..', base_dir .. ';')
    if type(project_root) == 'table' then
        project_root = project_root[1] or ''
    end

    local project_prefix = ''
    if project_root ~= '' then
        project_prefix = vim.fn.fnamemodify(project_root, ':t') .. '__'
    end

    local base_name
    if filetype == 'minifiles' or filetype == 'netrw' or filetype == 'oil' then
        base_name = vim.fn.fnamemodify(base_dir:gsub('/$', ''), ':t')
    else
        base_name = (#items > 0)
                and vim.fn.fnamemodify(items[1]:gsub('/$', ''), ':t')
            or 'project'
    end
    if base_name == '' then
        base_name = 'project'
    end

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local zip_name =
        string.format('%s%s__%s.nvim.zip', project_prefix, base_name, timestamp)

    local downloads = M.normalize_path(config.storage_path)
    if vim.fn.isdirectory(downloads) == 0 then
        vim.fn.mkdir(downloads, 'p')
    end
    local zip_path = downloads .. '/' .. zip_name

    -- Build relative paths for 7-Zip
    local rel_items = {}
    for _, f in ipairs(items) do
        local full = M.normalize_path(f)
        if full:sub(1, #base_dir) == base_dir then
            local rel = full:sub(#base_dir + 1)
            if rel ~= '.' and rel ~= '..' and rel ~= '' then
                table.insert(rel_items, string.format('"%s"', rel))
            end
        end
    end

    -- Fallback if rel_items is not a table
    if type(rel_items) ~= 'table' then
        rel_items = {}
    end
    if #rel_items == 0 then
        vim.notify(
            'No valid files to compress in base_dir',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    local binary = M.get_7zip_binary()
    if not binary then
        return
    end

    local uv = vim.loop

    -- OS-specific command
    if vim.fn.has 'win32' == 1 then
        -- Normalize Windows paths
        local base_dir_win = base_dir:gsub('/$', ''):gsub('/', '\\')
        local zip_path_win = zip_path:gsub('/', '\\')

        -- Convert rel_items to Windows format safely
        local rel_items_win = {}
        for i = 1, #rel_items do
            local r = rel_items[i]
            if type(r) == 'string' then
                rel_items_win[#rel_items_win + 1] = r:gsub('/', '\\')
            end
        end

        -- Quote binary if it contains spaces
        local binary_path = binary
        if binary_path:find ' ' then
            binary_path = string.format('"%s"', binary_path)
        end

        -- Build Windows command using & separator
        local cmd = string.format(
            '%s a -tzip "%s" %s -r',
            binary_path,
            zip_path_win,
            table.concat(rel_items_win, ' ')
        )
        local full_cmd = string.format('cd /d "%s" & %s', base_dir_win, cmd)
        local ok = os.execute(full_cmd)
        if ok ~= 0 then
            vim.notify(
                'Failed to create zip',
                vim.log.levels.ERROR,
                { title = 'yank-system-ops' }
            )
            return
        end
    else
        -- Linux/macOS
        local cmd = string.format(
            'cd "%s" ; %s a -tzip "%s" %s -r',
            base_dir,
            binary,
            zip_path,
            table.concat(rel_items, ' ')
        )
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify(
                'Failed to create zip: ' .. result,
                vim.log.levels.ERROR,
                { title = 'yank-system-ops' }
            )
            return
        end
    end

    -- Copy zip path to clipboard
    vim.fn.setreg('+', zip_path)

    -- Remove old archives
    local existing = vim.fn.globpath(downloads, '*.nvim.zip', true, true)
    table.sort(existing, function(a, b)
        return uv.fs_stat(a).mtime.sec > uv.fs_stat(b).mtime.sec
    end)
    for i = (config.files_to_keep + 1), #existing do
        os.remove(existing[i])
    end

    return zip_path
end

--- Compress selected files and copy the archive to the clipboard
function M.zip_files_to_clipboard(items, base_dir, filetype)
    local zip_path = M.create_zip(items, base_dir, filetype)
    if zip_path then
        os_module.add_files_to_clipboard(zip_path)
        vim.notify(
            'Compressed archive added to clipboard',
            vim.log.levels.INFO,
            { title = 'yank-system-ops' }
        )
    end
end

--- Extract an archive from clipboard into target directory
function M.extract_files_from_clipboard(target_dir)
    local ok = os_module:extract_files_from_clipboard(target_dir)
    if ok then
        ui.refresh_buffer_views()
        vim.notify(
            'Archive extracted successfully',
            vim.log.levels.INFO,
            { title = 'yank-system-ops' }
        )
    else
        vim.notify(
            'No valid archive found in clipboard',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
    end
end

return M
