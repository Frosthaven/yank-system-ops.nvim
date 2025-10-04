--- Darwin-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Darwin environments
-- @module yank_system_ops.os_module.Darwin
local Base = require('yank_system_ops.os_module.__base')
local Darwin = Base:extend()

--- Copy a single file (or multiple files) to macOS clipboard
-- @param files string|table File path(s) to copy
-- @return boolean success
function Darwin.add_files_to_clipboard(files)
    local function copy_file(file)
        local osa_cmd = string.format('osascript -e \'set the clipboard to POSIX file "%s"\'', file)
        local result = vim.fn.system(osa_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify('Failed to copy file to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
            return false
        end
        return true
    end

    if type(files) == 'string' then
        return copy_file(files)
    elseif type(files) == 'table' then
        for _, f in ipairs(files) do
            if not copy_file(f) then
                return false
            end
        end
        return true
    else
        vim.notify('Invalid input to add_files_to_clipboard', vim.log.levels.WARN, { title = 'Keymap' })
        return false
    end
end

--- Open a file or folder in Finder (or ForkLift if installed)
-- @param path string Absolute path to file or directory
-- @return boolean success
function Darwin.open_file_browser(path)
    if not path or path == '' then
        vim.notify('No path provided to open_file_browser', vim.log.levels.WARN, { title = 'Keymap' })
        return false
    end

    local forklift_path = '/Applications/ForkLift.app'
    local cmd

    if vim.fn.isdirectory(forklift_path) == 1 then
        cmd = string.format([[
            osascript -e 'tell application "ForkLift" to open POSIX file "%s"
                           tell application "ForkLift" to activate'
        ]], path)
    else
        if vim.fn.isdirectory(path) == 1 then
            cmd = string.format([[
                osascript -e 'tell application "Finder" to open POSIX file "%s"
                               tell application "Finder" to activate'
            ]], path)
        else
            cmd = string.format([[
                osascript -e 'tell application "Finder" to reveal POSIX file "%s"
                               tell application "Finder" to activate'
            ]], path)
        end
    end

    vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
        vim.notify('Opened file manager', vim.log.levels.INFO, { title = 'Keymap' })
        return true
    else
        vim.notify('Failed to open file manager', vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
end

return Darwin
