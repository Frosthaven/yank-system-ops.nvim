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
    vim.notify(
        vim.inspect(files),
        vim.log.levels.DEBUG,
        { title = 'yank-system-ops' }
    )
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

    -- Escape paths for PowerShell
    local escaped_files = {}
    for _, f in ipairs(files) do
        table.insert(escaped_files, "'" .. f:gsub("'", "''") .. "'")
    end
    local file_list = table.concat(escaped_files, ', ')

    -- Inline script block
    local ps = string.format(
        [=[
& {
    Add-Type -AssemblyName System.Windows.Forms
    $sc = New-Object System.Collections.Specialized.StringCollection
    %s | ForEach-Object { if (Test-Path $_) { $sc.Add($_) | Out-Null } }
    if ($sc.Count -gt 0) { [System.Windows.Forms.Clipboard]::SetFileDropList($sc); exit 0 } else { exit 2 }
}
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

    -- Handle SVG in clipboard text
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

    -- PowerShell script to copy files from clipboard
    local ps = [=[
Add-Type -AssemblyName System.Windows.Forms
try {
    $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
    if ($files.Count -eq 0) { exit 1 }
    foreach ($f in $files) {
        $dest = '%TARGET%'
        Copy-Item -LiteralPath $f -Destination $dest -Recurse -Force
    }
    exit 0
} catch {
    Write-Error $_.ToString()
    exit 1
}
]=]

    -- Replace placeholder with target_dir
    ps = ps:gsub('%%TARGET%%', target_dir)

    local result, rc = run_ps_script(ps)
    if rc ~= 0 then
        vim.notify(
            'Failed to put files from clipboard: ' .. (result or '<no output>'),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    vim.notify(
        'Files from clipboard pasted successfully',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
    return true
end

--- Open file or directory in Explorer
function Windows.open_file_browser(path)
    if not path or path == '' then
        vim.notify(
            'Invalid path for open_file_browser',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end
    local cmd = string.format('explorer "%s"', path)
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Check if clipboard has image
function Windows:clipboard_has_image()
    local ps = [=[
Add-Type -AssemblyName System.Windows.Forms
if ([System.Windows.Forms.Clipboard]::ContainsImage()) { exit 0 } else { exit 1 }
]=]
    vim.fn.system(
        'powershell -NoProfile -Command [Console]::OutputEncoding=[Text.Encoding]::UTF8; '
            .. ps
    )
    return vim.v.shell_error == 0
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
