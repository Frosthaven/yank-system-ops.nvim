--- Base OS module for yank_system_ops
-- Provides interface-like abstract methods to be overridden by OS-specific modules
-- @module Base
local Base = {}

--- Copy file(s) to the system clipboard
-- Abstract method. Must be implemented in subclass.
-- @param files string|table A file path or a list of file paths
function Base.add_files_to_clipboard(files)
    files = files or {}
    vim.notify(
        "add_files_to_clipboard not implemented for this OS",
        vim.log.levels.WARN,
        { title = "yank-system-ops" }
    )
end

--- Open a file or directory in the system's file browser
-- Abstract method. Must be implemented in subclass.
-- @param path string Absolute path to file or directory
function Base.open_file_browser(path)
    path = path or ""
    vim.notify(
        "open_file_browser not implemented for this OS",
        vim.log.levels.WARN,
        { title = "yank-system-ops" }
    )
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

