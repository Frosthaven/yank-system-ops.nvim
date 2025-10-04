-- yank_system_ops/os_module/base.lua
local Base = {}

function Base.add_files_to_clipboard(files)
    error("add_files_to_clipboard not implemented for this OS")
end

function Base.open_file_browser(path)
    error("open_file_browser not implemented for this OS")
end

-- Helper for inheritance
function Base:extend(subclass)
    subclass = subclass or {}
    setmetatable(subclass, { __index = self })
    return subclass
end

return Base

