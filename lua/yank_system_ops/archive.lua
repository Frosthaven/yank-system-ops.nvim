--- Archive handling for yank-system-ops
-- Compress files, manage old archives, and handle clipboard operations
-- @module yank_system_ops.archive
local M = {}

local loader = require 'yank_system_ops.__loader'
local ui = require 'yank_system_ops.ui'
local pathinfo = require 'yank_system_ops.pathinfo'

local os_module = loader.get_os_module()
local config = loader.get_config()

--- Get available 7z binary
-- @return string|nil Returns binary name or nil if not found
function M.get_7zip_binary()
    local possible_binaries = { '7z', '7zz' }
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

--- Compress files into a zip archive
-- @param items table List of file paths
-- @param base_dir string Base directory
-- @param filetype string Filetype context
-- @return string|nil Path to zip file
function M.create_zip(items, base_dir, filetype)
    items = pathinfo.filter_recursive_items(items)

    if not items or #items == 0 then
        vim.notify(
            'No files/folders to compress',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    if base_dir:sub(-1) ~= '/' then
        base_dir = base_dir .. '/'
    end

    local project_root = vim.fn.finddir('.git/..', base_dir .. ';')
    local project_prefix = ''
    if project_root ~= '' and type(project_root) == 'string' then
        project_prefix = vim.fn.fnamemodify(project_root, ':t') .. '__'
    end

    local base_name
    if filetype == 'minifiles' or filetype == 'netrw' then
        base_name = vim.fn.fnamemodify(base_dir:gsub('/$', ''), ':t')
    else
        base_name = vim.fn.fnamemodify(items[1]:gsub('/$', ''), ':t')
    end
    if base_name == '' then
        base_name = 'project'
    end

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local zip_name =
        string.format('%s%s__%s.nvim.zip', project_prefix, base_name, timestamp)

    local downloads = config.storage_path
    if vim.fn.isdirectory(downloads) == 0 then
        vim.fn.mkdir(downloads, 'p')
    end
    local zip_path = downloads .. '/' .. zip_name

    local rel_items = {}
    for _, f in ipairs(items) do
        local st = vim.loop.fs_stat(f)
        if st then
            local full = vim.fn.fnamemodify(f, ':p')
            if full:sub(1, #base_dir) == base_dir then
                local rel = full:sub(#base_dir + 1)
                if rel ~= '.' and rel ~= '..' then
                    table.insert(rel_items, string.format('"%s"', rel))
                end
            end
        end
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
    local cmd = string.format(
        '%s a -tzip "%s" %s -r',
        binary,
        zip_path,
        table.concat(rel_items, ' ')
    )
    local full_cmd = string.format('cd "%s" ; %s', base_dir, cmd)

    local result = vim.fn.system(full_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to create zip: ' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return
    end

    vim.fn.setreg('+', zip_path)

    local existing = vim.fn.globpath(downloads, '*.nvim.zip', true, true)
    table.sort(existing, function(a, b)
        return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
    end)
    for i = (config.files_to_keep + 1), #existing do
        os.remove(existing[i])
    end

    return zip_path
end

--- Compress selected files and copy the archive to the clipboard
-- @param items table
-- @param base_dir string
-- @param filetype string
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
-- @param target_dir string
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
