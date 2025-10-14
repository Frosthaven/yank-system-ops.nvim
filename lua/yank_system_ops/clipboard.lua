--- Clipboard operations for yank-system-ops
-- Handles copying files to the system clipboard and retrieving files from it
-- @module yank_system_ops.clipboard

local M = {}
local loader = require 'yank_system_ops.__loader'
local os_module = loader.get_os_module()
local ui = require 'yank_system_ops.ui'
local uri_downloader = require 'yank_system_ops.uri_downloader'
local pathinfo = require 'yank_system_ops.pathinfo'
local clipboard = require 'native_clipboard'

--- Copy files to system clipboard
-- @param items table List of file paths
-- @return boolean success
function M.yank_files(items)
    items = pathinfo.filter_recursive_items(items)

    if not items or #items == 0 then
        vim.notify(
            'No files selected to yank',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local ok = clipboard:set('files', items)
    if not ok then
        vim.notify(
            'Failed to copy files to clipboard',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    vim.notify(
        'Files copied to system clipboard',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
    return true
end

--- Paste/put files from system clipboard into target directory
-- Supports local files, images, or URLs
-- @param target_dir string Directory to save clipboard files
-- @return boolean success
function M.put_files(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if not target_dir or vim.fn.isdirectory(target_dir) == 0 then
        vim.notify(
            'Target directory not found',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local clip = vim.fn.getreg '+' or ''
    clip = vim.trim(clip)

    local success = false

    -- Handle URIs
    local is_url = clip:match '^https?://' or clip:match '^ftp://'
    if is_url then
        local path = uri_downloader.download(clip, target_dir)
        if path then
            ui.refresh_buffer_views()
            vim.notify(
                'URL downloaded successfully into: ' .. target_dir,
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
            return true
        else
            vim.notify(
                'Failed to download URL',
                vim.log.levels.ERROR,
                { title = 'yank-system-ops' }
            )
            return false
        end
    end

    -- Handle image data
    local has_image = clipboard:has 'image'
    if has_image then
        local img_path = os_module:save_clipboard_image(target_dir)
        if img_path then
            ui.refresh_buffer_views()
            vim.notify(
                'Image saved from clipboard: ' .. img_path,
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
            success = true
        end
    end

    -- Fallback: treat as local file paths
    if not success then
        success = os_module.put_files_from_clipboard(target_dir)
        if success then
            ui.refresh_buffer_views()
            vim.notify(
                'Clipboard files put successfully',
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
        else
            vim.notify(
                'No valid files found in clipboard',
                vim.log.levels.WARN,
                { title = 'yank-system-ops' }
            )
        end
    end

    return success
end

return M
