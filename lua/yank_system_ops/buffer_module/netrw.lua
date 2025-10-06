--- Netrw buffer module for yank_system_ops
-- Implements the buffer interface for Netrw file explorer
-- @module netrw
local Base = require 'yank_system_ops.buffer_module.__base'
local M = Base:extend()

--- Get list of files in the current buffer
-- Returns all files in the current Netrw directory
-- @return table|nil List of full file paths, or nil if none found
function M.get_files()
    local dir = M.get_active_dir()
    if not dir or vim.fn.isdirectory(dir) == 0 then
        return nil
    end

    local items = {}

    -- Include normal files/folders
    local visible = vim.fn.globpath(dir, '*', true, true)
    for _, f in ipairs(visible) do
        if vim.loop.fs_stat(f) then
            table.insert(items, f)
        end
    end

    -- Include hidden files/folders (dotfiles)
    local hidden = vim.fn.globpath(dir, '.*', true, true)
    for _, f in ipairs(hidden) do
        -- skip '.' and '..'
        local base = vim.fn.fnamemodify(f, ':t')
        if base ~= '.' and base ~= '..' and vim.loop.fs_stat(f) then
            table.insert(items, f)
        end
    end

    return #items > 0 and items or nil
end

--- Get the active directory of the buffer
-- Returns the current Netrw directory or fallback to current working directory
-- @return string|nil Absolute path of directory, or nil if invalid
function M.get_active_dir()
    local path = vim.b.netrw_curdir or vim.fn.getcwd()
    if path and vim.fn.isdirectory(path) == 1 then
        return path
    end
    return nil
end

--- Refresh the Netrw view
function M.refresh_view()
    vim.cmd 'Explore'
end

return M
