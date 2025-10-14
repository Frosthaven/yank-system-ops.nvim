--- Windows-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Windows environments
-- @module yank_system_ops.os_module.Windows
local Base = require 'yank_system_ops.os_module.__base'
local Windows = Base:extend()

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

    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify(
            'Target directory not found: ' .. target_dir,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Step 1: Check clipboard for SVG/text content
    local clip = vim.fn.getreg '+' or ''
    clip = vim.trim(clip)
    if clip:match '^<svg' then
        local timestamp = os.date '%Y%m%d_%H%M%S'
        local svg_file =
            string.format('%s\\clipboard_%s.svg', target_dir, timestamp)
        local f = io.open(svg_file, 'w')
        if f then
            f:write(clip)
            f:close()
            vim.notify(
                'SVG content saved to: ' .. svg_file,
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
            return true
        else
            vim.notify(
                'Failed to write SVG to: ' .. svg_file,
                vim.log.levels.ERROR,
                { title = 'yank-system-ops' }
            )
            return false
        end
    end

    -- Step 2: Fall back to file paths
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

--- Save clipboard image, HTML <img> content, or SVG to target directory (Windows)
-- Prefers SVG or base64 images to preserve transparency. Falls back to bitmap if necessary.
-- @param target_dir string: destination directory
-- @return string|nil: path to saved image, or nil on failure
function Windows:save_clipboard_image(target_dir)
    if not target_dir or vim.fn.isdirectory(target_dir) == 0 then
        vim.notify(
            'Invalid target directory: ' .. tostring(target_dir),
            vim.log.levels.ERROR
        )
        return nil
    end

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local out_path

    -- Step 1: Check for SVG content in clipboard
    local clip = vim.fn.getreg '+' or ''
    clip = vim.trim(clip)
    if clip:match '^<svg' then
        out_path =
            vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp .. '.svg')
        local f = io.open(out_path, 'w')
        if f then
            f:write(clip)
            f:close()
            vim.notify(
                'Saved SVG content to: ' .. out_path,
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
            return out_path
        else
            vim.notify(
                'Failed to write SVG to: ' .. out_path,
                vim.log.levels.ERROR,
                { title = 'yank-system-ops' }
            )
            return nil
        end
    end

    -- Step 2: Check HTML <img> base64 or URL
    out_path = vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp)
    local ps_script = string.format(
        [[
Add-Type -AssemblyName System.Windows.Forms
$data = [System.Windows.Forms.Clipboard]::GetDataObject()
$imgSaved = $false

if ($data.GetDataPresent([System.Windows.Forms.DataFormats]::Html)) {
    $html = $data.GetData([System.Windows.Forms.DataFormats]::Html) -as [string]

    # Embedded base64 image
    if ($html -match '<img[^>]+src="data:image/(png|jpeg|jpg);base64,([^"]+)"') {
        $ext = $matches[1]
        $out = "%s." + $ext
        [IO.File]::WriteAllBytes($out, [Convert]::FromBase64String($matches[2]))
        $imgSaved = $true
        Write-Output $out
    }
    # Linked URL
    elseif ($html -match '<img[^>]+src="(https?://[^"]+)"') {
        $url = $matches[1]
        $out = "%s.png"
        try {
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
            $imgSaved = $true
            Write-Output $out
        } catch {
            Write-Host "Failed to download image from $url"
        }
    }
}

if (-not $imgSaved) { exit 1 } else { exit 0 }
]],
        out_path,
        out_path
    )

    local result = vim.fn.system {
        'powershell',
        '-NoProfile',
        '-STA',
        '-Command',
        '[Console]::OutputEncoding=[Text.Encoding]::UTF8; ' .. ps_script,
    }
    if vim.v.shell_error == 0 then
        local saved_file = vim.fn.trim(result)
        if vim.fn.filereadable(saved_file) == 1 then
            return Windows:fix_image_extension(saved_file) or saved_file
        end
    end

    -- Step 3: Fallback to bitmap (may lose transparency)
    out_path = vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp .. '.png')
    local ps_bitmap = string.format(
        [[
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$bmp = [System.Windows.Forms.Clipboard]::GetImage()
if ($bmp) {
    $bmp.Save("%s", [System.Drawing.Imaging.ImageFormat]::Png)
    exit 0
} else { exit 1 }
]],
        out_path
    )

    local result_bitmap = vim.fn.system {
        'powershell',
        '-NoProfile',
        '-STA',
        '-Command',
        '[Console]::OutputEncoding=[Text.Encoding]::UTF8; ' .. ps_bitmap,
    }
    if vim.v.shell_error == 0 and vim.fn.filereadable(out_path) == 1 then
        return Windows:fix_image_extension(out_path) or out_path
    end

    vim.notify(
        'No compatible image found in clipboard.\nPowerShell output:\n'
            .. tostring(result_bitmap),
        vim.log.levels.WARN,
        { title = 'yank-system-ops' }
    )
    return nil
end

--- Open a file or folder in Explorer (Windows)
-- Opens the folder in Explorer. If `path` is a file, selects it.
-- @param path string Absolute path to file or folder
-- @return boolean True on success, false on failure
function Windows.open_file_browser(path)
    if not path or path == '' then
        vim.notify(
            'No path provided to open in Explorer',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Normalize path: convert / to \ and remove trailing backslash
    path = path:gsub('/', '\\'):gsub('\\+$', '')

    local is_dir = vim.fn.isdirectory(path) == 1
    local cmd

    if is_dir then
        -- Open folder
        cmd = string.format('explorer.exe "%s"', path)
    else
        -- Select file in folder
        local abs_path = vim.fn.fnamemodify(path, ':p')
        abs_path = abs_path:gsub('/', '\\')
        cmd = string.format('explorer.exe /select,"%s"', abs_path)
    end

    local ok, msg, _ = os.execute(cmd)
    if not ok then
        vim.notify(
            'Failed to open Explorer for path: '
                .. path
                .. '\n'
                .. tostring(msg),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    return true
end

return Windows
