--- Minifiles buffer module for yank_system_ops
-- Implements the buffer interface for mini.files
-- @module minifiles
local Base = require('yank_system_ops.buffer_module.__base')
local M = Base:extend()

local minifile = require('mini.files')

--- Get list of files in the current buffer
-- Returns all files in the directory if buffer points to a directory,
-- or the single file if buffer points to a file
-- @return table|nil List of full file paths, or nil if none found
function M.get_files()
    local items = {}
    local curr_path = vim.fn.expand('%:p'):gsub('^minifiles://%d+//', '/')
    local stat = vim.loop.fs_stat(curr_path)

    if stat then
        if stat.type == 'directory' then
            local scan = vim.fn.globpath(curr_path, '*', true, true)
            for _, f in ipairs(scan) do
                if vim.loop.fs_stat(f) then
                    table.insert(items, f)
                end
            end
        else
            table.insert(items, curr_path)
        end
    end

    return #items > 0 and items or nil
end

--- Get the active directory of the buffer
-- Returns the directory if buffer points to a directory, or parent directory if a file
-- @return string|nil Absolute path of directory, or nil if invalid
function M.get_active_dir()
    local path = vim.fn.expand('%:p'):gsub('^minifiles://%d+//', '/')
    local stat = vim.loop.fs_stat(path)
    if stat then
        return stat.type == 'directory' and path or vim.fn.fnamemodify(path, ':h')
    end
    return nil
end

--- Refresh the view for the buffer
function M.refresh_view()
    minifile.open()
end

return M
