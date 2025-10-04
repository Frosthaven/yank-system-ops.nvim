-- yank_system_ops/os_module/Windows_NT.lua
local Base = require("yank_system_ops.os_module.__base")
local Windows = Base:extend()

function Windows.add_files_to_clipboard(files)
    if type(files) == 'string' then
        files = { files }
    end

    local ps_files = {}
    for _, f in ipairs(files) do
        table.insert(ps_files, "'" .. f .. "'")
    end

    local ps_cmd = 'powershell -Command "[System.Windows.Forms.Clipboard]::SetFileDropList((New-Object System.Collections.Specialized.StringCollection; ' ..
                   table.concat(ps_files, '; $_.Add(') .. ')))"'

    local result = vim.fn.system(ps_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to copy file(s) to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

function Windows.open_file_browser(path)
    local ps_cmd = string.format('explorer "%s"', path)
    local result = vim.fn.system(ps_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to open file browser: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

return Windows
