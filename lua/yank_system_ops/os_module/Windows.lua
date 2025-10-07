--- Windows-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Windows environments
-- @module yank_system_ops.os_module.Windows
local Base = require 'yank_system_ops.os_module.__base'
local Windows = Base:extend()

-- Helper: run a PowerShell script with arguments
local function run_ps_script(script, args)
    args = args or {}
    local arg_str = table.concat(args, ' ')
    local cmd = string.format(
        'powershell -NoProfile -Command [Console]::OutputEncoding=[Text.Encoding]::UTF8; %s %s',
        script,
        arg_str
    )
    local output = vim.fn.system(cmd)
    return output, vim.v.shell_error
end

--- Copy file(s) to the clipboard (Windows)
-- Uses PowerShell + System.Windows.Forms.Clipboard
-- @param files string|table
-- @return boolean
function Windows.add_files_to_clipboard(files)
    if type(files) == 'string' then
        files = { files }
    end
    if type(files) ~= 'table' or #files == 0 then
        vim.notify(
            'No files provided to copy',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Escape paths
    local escaped_files = {}
    for _, f in ipairs(files) do
        table.insert(escaped_files, "'" .. f:gsub("'", "''") .. "'")
    end
    local file_list = table.concat(escaped_files, ', ')

    -- PowerShell script
    local ps = string.format(
        [=[
Add-Type -AssemblyName System.Windows.Forms
$sc = New-Object System.Collections.Specialized.StringCollection
%s | ForEach-Object { if (Test-Path $_) { $sc.Add($_) | Out-Null } }
if ($sc.Count -gt 0) {
    [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
    exit 0
} else { exit 1 }
]=],
        file_list
    )

    local result = vim.fn.system { 'powershell', '-NoProfile', '-Command', ps }
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to copy file(s) to clipboard: ' .. (result or '<no output>'),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end
    return true
end

--- Put files from clipboard into target_dir
-- @param target_dir string
-- @return boolean
function Windows.put_files_from_clipboard(target_dir)
    if not target_dir or target_dir == '' then
        vim.notify(
            'No target directory specified',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Replace backslashes for PowerShell
    local ps_target = target_dir:gsub('\\', '/')

    local ps = string.format(
        [=[
Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Milliseconds 50
$files = [System.Windows.Forms.Clipboard]::GetFileDropList()
if ($files.Count -eq 0) { exit 1 }
$dest = "%s"
foreach ($f in $files) {
    Copy-Item -LiteralPath $f -Destination $dest -Recurse -Force
}
exit 0
]=],
        ps_target
    )

    local result, rc =
        vim.fn.system { 'powershell', '-NoProfile', '-STA', '-Command', ps },
        vim.v.shell_error
    if rc ~= 0 then
        vim.notify(
            'Failed to paste files. PowerShell output:\n'
                .. (result or '<no output>'),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    return true
end

--- Extract an archive from the clipboard into a target directory (Windows)
-- @param target_dir string Absolute path to extract into
-- @return table|nil List of extracted file paths or nil on failure
function Windows:extract_files_from_clipboard(target_dir)
    if not target_dir or target_dir == '' then
        vim.notify('No target directory specified', vim.log.levels.ERROR, {
            title = 'yank-system-ops',
        })
        return nil
    end

    -- Ensure 7z exists in PATH
    if vim.fn.executable '7z' == 0 then
        vim.notify('7z executable not found in PATH', vim.log.levels.ERROR, {
            title = 'yank-system-ops',
        })
        return nil
    end

    -- PowerShell: retrieve first file from clipboard and copy it to target_dir
    local ps = string.format(
        [=[
Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Milliseconds 50
$files = [System.Windows.Forms.Clipboard]::GetFileDropList()
if ($files.Count -eq 0) { exit 2 }

$src = $files[0]
if (-not (Test-Path $src)) { exit 3 }

$target = "%s"
$dest = Join-Path $target (Split-Path $src -Leaf)
Copy-Item -LiteralPath $src -Destination $dest -Force
Write-Output $dest
exit 0
]=],
        target_dir:gsub('\\', '/')
    )

    local output =
        vim.fn.system { 'powershell', '-NoProfile', '-STA', '-Command', ps }
    local rc = vim.v.shell_error
    if rc ~= 0 then
        vim.notify(
            'Failed to retrieve archive from clipboard.\nPowerShell output:\n'
                .. (output or '<none>'),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    local archive_path = vim.fn.trim(output)
    if archive_path == '' or vim.fn.filereadable(archive_path) == 0 then
        vim.notify(
            'No valid archive copied from clipboard.',
            vim.log.levels.WARN,
            {
                title = 'yank-system-ops',
            }
        )
        return nil
    end

    -- Extract the copied archive into target_dir
    local extract_cmd =
        string.format('7z x "%s" -o"%s" -y', archive_path, target_dir)
    local ok = os.execute(extract_cmd)
    if ok ~= 0 then
        vim.notify(
            'Failed to extract archive: ' .. archive_path,
            vim.log.levels.ERROR,
            {
                title = 'yank-system-ops',
            }
        )
        return nil
    end

    -- Cleanup: remove the copied archive file
    local delete_cmd = string.format(
        'powershell -NoProfile -Command Remove-Item -LiteralPath "%s" -Force',
        archive_path
    )
    os.execute(delete_cmd)

    return { archive_path }
end

--- Check if clipboard has image
function Windows:clipboard_has_image()
    return false
    --     local ps = [=[
    -- Add-Type -AssemblyName System.Windows.Forms
    -- $data = [System.Windows.Forms.Clipboard]::GetDataObject()
    --
    -- # If clipboard has files, ignore image
    -- if ($data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { exit 1 }
    --
    -- # Check for real image formats
    -- $formats = $data.GetFormats()
    -- if ($formats -contains "Bitmap" -or $formats -contains "PNG") { exit 0 } else { exit 1 }
    -- ]=]
    --
    --     vim.fn.system(
    --         'powershell -NoProfile -Command [Console]::OutputEncoding=[Text.Encoding]::UTF8; '
    --             .. ps
    --     )
    --     return vim.v.shell_error == 0
end

--- Save clipboard image
function Windows:save_clipboard_image(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify(
            'Target directory not found: ' .. tostring(target_dir),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    local filename = 'clipboard_image_' .. os.date '%Y%m%d_%H%M%S' .. '.png'
    local out_path = target_dir .. '\\' .. filename

    local ps = string.format(
        [=[
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    $img.Save("%s", [System.Drawing.Imaging.ImageFormat]::Png)
} else { exit 1 }
]=],
        out_path
    )

    local result, rc = run_ps_script(ps)
    if rc ~= 0 then
        vim.notify(
            'Failed to save clipboard image:\n' .. (result or '<no output>'),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    return out_path
end

return Windows
