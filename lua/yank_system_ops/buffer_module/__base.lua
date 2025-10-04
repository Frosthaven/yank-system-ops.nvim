--- Base Buffer module for yank_system_ops
-- Provides interface-like abstract methods to be overridden by buffer-specific
-- modules This module is used when no other buffer type module matches the
-- current buffer. It handles basic file buffers.
-- @module BaseBuffer
local Base = {}

--- Get a list of files in the current buffer context
-- Abstract method. Must be implemented in subclass.
-- @return table List of full file paths
function Base.get_files()
    local items = {}
    local curr_path = vim.fn.expand('%:p')
    local stat = vim.loop.fs_stat(curr_path)

    if stat and stat.type == 'file' then
        table.insert(items, curr_path)
    end

    return #items > 0 and items or nil
end

--- Get the active directory for the buffer context
-- Abstract method. Must be implemented in subclass.
-- @return string Path to active directory
function Base.get_active_dir()
    local path = vim.fn.expand('%:p')
    local stat = vim.loop.fs_stat(path)
    if stat then
        return stat.type == 'directory' and path or vim.fn.fnamemodify(path, ':h')
    end
    return vim.fn.getcwd()
end

--- Refresh the view for the buffer context
-- Abstract method. Must be implemented in subclass.
function Base.refresh_view()
    -- default file buffers do not need special refresh logic
end

--- Helper for inheritance
-- @param subclass table Optional table to extend from this base
-- @return table Subclass table with metatable set for inheritance
function Base:extend(subclass)
    subclass = subclass or {}
    setmetatable(subclass, { __index = self })
    return subclass
end

return Base
