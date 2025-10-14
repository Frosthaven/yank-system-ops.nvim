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

--- Correct the file extension based on actual content
-- @param path string: path to the downloaded file
-- @return string|nil: new path with correct extension, or nil on failure
function Base:fix_image_extension(path)
    if vim.fn.filereadable(path) == 0 then
        return nil
    end

    local f = io.open(path, 'rb')
    if not f then
        return nil
    end
    local header = f:read(512)
    f:close()

    local ext
    if header:match '^<svg' then
        ext = 'svg'
    elseif header:sub(1, 8) == '\137PNG\r\n\26\n' then
        ext = 'png'
    elseif header:sub(1, 2) == '\255\216' then
        ext = 'jpg'
    end

    if ext then
        local new_path = path:gsub('%.%w+$', '.' .. ext)
        if new_path ~= path then
            os.rename(path, new_path)
            return new_path
        end
        return path
    end

    return path
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
