--- Base OS module for yank_system_ops
-- Provides interface-like abstract methods to be overridden by OS-specific modules
-- @module Base
local Base = {}

--- Put file(s) from the system clipboard to a target directory
-- Abstract method. Must be implemented in subclass.
-- @param target_dir string Absolute path to target directory
function Base.put_files_from_clipboard(target_dir)
    target_dir = target_dir or ''
    vim.notify(
        'put_files_from_clipboard not implemented for this OS',
        vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
end

--- Extract files from clipboard into a target directory
-- Abstract method. Must be implemented by OS-specific modules.
-- @param target_dir string Absolute path
-- @return table List of extracted file paths or nil on failure
function Base:extract_files_from_clipboard(target_dir)
    target_dir = target_dir or ''
    vim.notify(
        'extract_files_from_clipboard not implemented for this OS',
        vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
    return nil
end

--- Open a file or directory in the system's file browser
-- Abstract method. Must be implemented in subclass.
-- @param path string Absolute path to file or directory
function Base.open_file_browser(path)
    path = path or ''
    vim.notify(
        'open_file_browser not implemented for this OS',
        vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
end

--- Default stub for saving clipboard images
-- @param target_dir string Directory to save image
-- @return string|nil Path to saved image or nil if unsupported
function Base:save_clipboard_image(target_dir)
    target_dir = target_dir or ''
    vim.notify(
        'save_clipboard_image not implemented for this OS',
        vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
    return nil
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
