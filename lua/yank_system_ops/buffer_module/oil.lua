--- Oil.nvim buffer module for yank_system_ops
-- Implements the buffer interface for oil.nvim
-- @module oil
local Base = require('yank_system_ops.buffer_module.__base')
local M = Base:extend()
local oil = require('oil')

--- Get list of files in the current buffer
-- Returns all files in the current oil.nvim directory
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
-- Returns the current oil.nvim directory or fallback to current working directory
-- @return string|nil Absolute path of directory, or nil if invalid
function M.get_active_dir()
    local path = vim.fn.expand('%:p'):gsub('^oil:///', '/')
    local stat = vim.loop.fs_stat(path)
    if stat then
        return stat.type == 'directory' and path or vim.fn.fnamemodify(path, ':h')
    end
    return nil
end

--- Refresh the oil.nvim view
function M.refresh_view()
    local buf = vim.api.nvim_get_current_buf()
    local ok, view = pcall(require('oil').get_view, buf)
    if ok and view then
        view:refresh()
    else
        -- fallback: open a new oil buffer at current dir
        local dir = M.get_active_dir()
        if dir then require('oil').open(dir) end
    end
end

return M
