--- Windows-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Windows environments
-- @module yank_system_ops.os_module.Windows_NT
local Base = require("yank_system_ops.os_module.__base")
local Windows = Base:extend()

--- Copy file(s) to the system clipboard
-- Uses PowerShell and the .NET `System.Windows.Forms.Clipboard` class
-- @param files string|table A file path or list of file paths
-- @return boolean True if copied successfully, false otherwise
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
        vim.notify(
            'Failed to copy file(s) to clipboard: ' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end
    return true
end

--- Put file(s) from the Windows clipboard into a target directory
-- Uses PowerShell to access clipboard contents via the
-- `System.Windows.Forms.Clipboard` .NET class and copy them into the target
-- directory.
-- @param target_dir string Absolute path to directory where files will be put
-- @return boolean True if put operation succeeded, false otherwise
function Windows.put_files_from_clipboard(target_dir)
    if not target_dir or target_dir == "" then
        vim.notify("No target directory specified", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local ps_cmd = [[
        powershell -Command "
            Add-Type -AssemblyName System.Windows.Forms
            $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
            if ($files.Count -eq 0) { exit 1 }
            foreach ($f in $files) {
                Copy-Item -LiteralPath $f -Destination ']] .. target_dir .. [[' -Recurse -Force
            }
        "
    ]]

    local result = vim.fn.system(ps_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to put files from clipboard: " .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    vim.notify("Put files from clipboard successfully", vim.log.levels.INFO, { title = "yank-system-ops" })
    return true
end

--- Open a file or directory in the system's file browser
-- Uses Windows Explorer
-- @param path string Absolute path to file or directory
-- @return boolean True if opened successfully, false otherwise
function Windows.open_file_browser(path)
    local ps_cmd = string.format('explorer "%s"', path)
    local result = vim.fn.system(ps_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to open file browser: ' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end
    return true
end

--- Check if clipboard contains image data (Windows)
-- @return boolean True if clipboard has image
function Windows:clipboard_has_image()
    local ps_script = [[
        Add-Type -AssemblyName System.Windows.Forms
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) { exit 0 } else { exit 1 }
    ]]
    local cmd = string.format('powershell -NoProfile -Command "%s"', ps_script:gsub('"', '\\"'))
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Save image from Windows clipboard to target_dir
-- Uses PowerShell
-- @param target_dir string Directory to save the image
-- @return string|nil Path to saved file or nil if no image found
function Windows:save_clipboard_image(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found: " .. tostring(target_dir), vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    local filename = "clipboard_image_" .. os.date("%Y%m%d_%H%M%S") .. ".png"
    local out_path = target_dir .. "\\" .. filename

    local ps_script = string.format([[
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
            $img = [System.Windows.Forms.Clipboard]::GetImage()
            $img.Save("%s", [System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            exit 1
        }
    ]], out_path)

    local cmd = string.format('powershell -NoProfile -Command "%s"', ps_script:gsub('"', '\\"'))
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to save clipboard image:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    return out_path
end

return Windows
