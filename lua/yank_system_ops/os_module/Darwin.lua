--- Darwin-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Darwin environments
-- @module yank_system_ops.os_module.Darwin
local Base = require 'yank_system_ops.os_module.__base'
local Darwin = Base:extend()

local clipboard = require 'native_clipboard'

--- Helper to quote shell arguments safely
local function shell_quote(str)
    return "'" .. str:gsub("'", "'\\''") .. "'"
end

--- Recursively extract an archive into a target directory on Darwin
-- Handles nested archives like .tar inside .zip
-- @param archive_path string Full path to archive
-- @param target_dir string Directory to extract into
-- @return boolean success
local function extract_archive_recursive(
    archive_path,
    target_dir,
    remove_original
)
    remove_original = remove_original ~= false -- default: remove original after extraction

    if not archive_path or vim.fn.filereadable(archive_path) == 0 then
        vim.notify(
            'Archive not found: ' .. tostring(archive_path),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Record files before extraction
    local before = vim.fn.glob(target_dir .. '/*', false, true)

    -- Extract archive with 7z
    local cmd = string.format('7z x -y "%s" -o"%s"', archive_path, target_dir)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Extraction failed:\n' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Record files after extraction
    local after = vim.fn.glob(target_dir .. '/*', false, true)

    -- Determine new files created by this extraction
    local new_files = {}
    local before_set = {}
    for _, f in ipairs(before) do
        before_set[f] = true
    end
    for _, f in ipairs(after) do
        if not before_set[f] then
            table.insert(new_files, f)
        end
    end

    -- Recursively extract any nested archives
    for _, f in ipairs(new_files) do
        if
            f:match '%.tar$'
            or f:match '%.tgz$'
            or f:match '%.tar%.gz$'
            or f:match '%.tar%.bz2$'
            or f:match '%.tar%.xz$'
        then
            local ok = extract_archive_recursive(f, target_dir)
            os.remove(f) -- remove nested archive
            if not ok then
                return false
            end
        end
    end

    -- Remove the original archive if desired
    if remove_original then
        os.remove(archive_path)
    end

    return true
end

--- Extract archive from clipboard on macOS using Swift helper
-- @param target_dir string Directory to extract into
-- @return boolean success
function Darwin:extract_files_from_clipboard(target_dir)
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

    -- Resolve the Swift helper relative to this Lua file
    local this_path = debug.getinfo(1, 'S').source
    if this_path:sub(1, 1) == '@' then
        this_path = this_path:sub(2)
    end
    local plugin_root = vim.fn.fnamemodify(this_path, ':h:h:h:h') -- adjust depth as needed
    local swift_file = plugin_root
        .. '/lua/yank_system_ops/os_module/Darwin/Darwin_extractarchive.swift'

    if not vim.loop.fs_stat(swift_file) then
        vim.notify(
            'Swift file not found: ' .. swift_file,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Build the command: swift <swift_file> <target_dir>
    local cmd = { 'bash', '-c', 'swift "$@"', 'dummy', swift_file, target_dir }
    local result = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to extract archive from clipboard:\n' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Swift prints the path of the archive it saved; now recursively extract
    local archive_path = vim.fn.trim(result)
    local ok = extract_archive_recursive(archive_path, target_dir)
    if ok then
        return true
    else
        return false
    end
end

--- Put files from clipboard into target directory using Swift helper
-- @param target_dir string Absolute path
-- @return boolean True on success, false on failure
function Darwin.put_files_from_clipboard(target_dir)
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

    -- Step 1: Check clipboard for SVG content
    local text_or_html = clipboard:get 'html' or clipboard:get 'text' or ''
    text_or_html = vim.trim(text_or_html)
    if text_or_html:match '^<svg' then
        -- Add timestamp to filename
        local timestamp = os.date '%Y%m%d_%H%M%S'
        local svg_file =
            string.format('%s/clipboard_%s.svg', target_dir, timestamp)

        local f = io.open(svg_file, 'w')
        if f then
            f:write(text_or_html)
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

    -- Step 2: Call existing Swift helper for files
    local this_path = debug.getinfo(1, 'S').source
    if this_path:sub(1, 1) == '@' then
        this_path = this_path:sub(2)
    end
    local plugin_root = vim.fn.fnamemodify(this_path, ':h:h:h:h')
    local swift_file = plugin_root
        .. '/lua/yank_system_ops/os_module/Darwin/Darwin_pastefiles.swift'

    if not vim.loop.fs_stat(swift_file) then
        vim.notify(
            'Swift file not found: ' .. swift_file,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local cmd = { 'bash', '-c', 'swift "$@"', 'dummy', swift_file, target_dir }
    local result = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to paste from clipboard:\n' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    return true
end

--- Open a file or folder in Finder (or ForkLift)
function Darwin.open_file_browser(path)
    if not path or path == '' then
        vim.notify(
            'No path provided to open_file_browser',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local forklift_path = '/Applications/ForkLift.app'
    local cmd

    if vim.fn.isdirectory(forklift_path) == 1 then
        cmd = string.format(
            [[
            osascript -e 'tell application "ForkLift" to open POSIX file "%s"
                           tell application "ForkLift" to activate'
        ]],
            path
        )
    elseif vim.fn.isdirectory(path) == 1 then
        cmd = string.format(
            [[
            osascript -e 'tell application "Finder" to open POSIX file "%s"
                           tell application "Finder" to activate'
        ]],
            path
        )
    else
        cmd = string.format(
            [[
            osascript -e 'tell application "Finder" to reveal POSIX file "%s"
                           tell application "Finder" to activate'
        ]],
            path
        )
    end

    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Save image from clipboard into target directory (Darwin/macOS)
function Darwin:save_clipboard_image(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify(
            'Target directory not found: ' .. tostring(target_dir),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local text_or_html = clipboard:get 'html' or clipboard:get 'text' or ''

    -- Step 1: Check for SVG content
    if text_or_html:match '^<svg' then
        local out_path =
            vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp .. '.svg')
        local f = io.open(out_path, 'w')
        if f then
            f:write(text_or_html)
            f:close()
            vim.notify(
                'Saved SVG content to: ' .. out_path,
                vim.log.levels.INFO,
                { title = 'yank-system-ops' }
            )
            return Darwin:fix_image_extension(out_path) or out_path
        end
    end

    -- Step 2: Check for HTML <img> with base64 or URL
    if text_or_html:match '^<img' then
        local img_type, base64_data =
            text_or_html:match '<img[^>]+src="data:image/(%w+);base64,([^"]+)"'
        if base64_data then
            local out_path = vim.fs.joinpath(
                target_dir,
                'clipboard_' .. timestamp .. '.' .. img_type
            )
            local f = io.open(out_path, 'wb')
            if f then
                f:write(
                    vim.fn.systemlist('base64 --decode', base64_data)[1] or ''
                )
                f:close()
                vim.notify(
                    'Saved base64 image to: ' .. out_path,
                    vim.log.levels.INFO,
                    { title = 'yank-system-ops' }
                )
                return Darwin:fix_image_extension(out_path) or out_path
            end
        end

        local url = text_or_html:match '<img[^>]+src="(https?://[^"]+)"'
        if url then
            local out_path =
                vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp .. '.png')
            local result =
                vim.fn.system { 'curl', '-L', '-s', '-o', out_path, url }
            if
                vim.v.shell_error == 0
                and vim.fn.filereadable(out_path) == 1
            then
                vim.notify(
                    'Downloaded image from: ' .. url,
                    vim.log.levels.INFO,
                    { title = 'yank-system-ops' }
                )
                return Darwin:fix_image_extension(out_path) or out_path
            end
        end
    end

    -- Step 3: Fallback to bitmap (pngpaste or AppleScript)
    local filename = 'clipboard_image_' .. timestamp .. '.png'
    local out_path = target_dir .. '/' .. filename

    local cmd
    if vim.fn.executable 'pngpaste' == 1 then
        cmd = string.format('pngpaste "%s"', out_path)
    else
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
        local safe_path = out_path:gsub('"', '\\"')
        cmd = string.format(
            'osascript -e %s',
            shell_quote(script:format(safe_path))
        )
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Failed to save clipboard image:\n' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    return Darwin:fix_image_extension(out_path) or out_path
end

return Darwin
