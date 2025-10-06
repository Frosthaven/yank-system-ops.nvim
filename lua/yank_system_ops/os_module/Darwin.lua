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
            vim.notify('Failed to copy file to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'yank-system-ops' })
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
        vim.notify('Invalid input to add_files_to_clipboard', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return false
    end
end

--- Put file(s) from the macOS clipboard into a target directory
-- Reads file paths from the clipboard using AppleScript and copies them into
-- the specified target directory.
-- @param target_dir string Absolute path to the directory where files will be
-- put
-- @return boolean True if put operation succeeded, false otherwise
function Darwin.put_files_from_clipboard(target_dir)
    if not target_dir or target_dir == '' then
        vim.notify('No target directory specified', vim.log.levels.ERROR, { title = 'yank-system-ops' })
        return false
    end

    local osa_cmd = [[osascript -e 'get the clipboard as text']]
    local result = vim.fn.system(osa_cmd)
    if vim.v.shell_error ~= 0 or result == '' then
        vim.notify('Clipboard is empty or unreadable', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return false
    end

    local files = {}
    for line in result:gmatch('[^\r\n]+') do
        local path = line:gsub('^file://', '')
        if vim.loop.fs_stat(path) then
            table.insert(files, path)
        end
    end

    if #files == 0 then
        vim.notify('No valid file paths found in clipboard', vim.log.levels.WARN, { title = 'yank-system-ops' })
        return false
    end

    for _, f in ipairs(files) do
        local cmd = string.format('cp -R "%s" "%s/"', f, target_dir)
        vim.fn.system(cmd)
    end

    vim.notify('Put ' .. #files .. ' file(s) from clipboard', vim.log.levels.INFO, { title = 'yank-system-ops' })
    return true
end

--- Open a file or folder in Finder (or ForkLift if installed)
-- @param path string Absolute path to file or directory
-- @return boolean success
function Darwin.open_file_browser(path)
    if not path or path == '' then
        vim.notify('No path provided to open_file_browser', vim.log.levels.WARN, { title = 'yank-system-ops' })
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
        vim.notify('Opened file manager', vim.log.levels.INFO, { title = 'yank-system-ops' })
        return true
    else
        vim.notify('Failed to open file manager', vim.log.levels.ERROR, { title = 'yank-system-ops' })
        return false
    end
end

--- Save image from macOS clipboard to target_dir
-- Uses pngpaste if available, otherwise falls back to AppleScript
-- @param target_dir string Directory to save the image
-- @return string|nil Path to saved file or nil if no image found
function Darwin:save_clipboard_image(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found: " .. tostring(target_dir), vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    local filename = "clipboard_image_" .. os.date("%Y%m%d_%H%M%S") .. ".png"
    local out_path = target_dir .. "/" .. filename

    local cmd
    if vim.fn.executable("pngpaste") == 1 then
        cmd = string.format('pngpaste "%s"', out_path)
    else
        -- AppleScript fallback
        local script = [[
            set theFile to POSIX file "%s"
            try
                set theData to the clipboard as «class PNGf»
                set outFile to open for access theFile with write permission
                write theData to outFile
                close access outFile
            on error errMsg
                try
                    close access theFile
                end try
                error errMsg
            end try
        ]]
        -- Escape quotes in path for AppleScript
        local safe_path = out_path:gsub('"', '\\"')
        cmd = string.format('osascript -e \'%s\'', script:format(safe_path))
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to save clipboard image:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    return out_path
end

return Darwin
