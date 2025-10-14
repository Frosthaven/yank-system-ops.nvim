--- Linux-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Linux environments
-- @module yank_system_ops.os_module.Linux
local Base = require 'yank_system_ops.os_module.__base'
local Linux = Base:extend()

local clipboard = require 'native_clipboard'

--- Put file(s) from system clipboard into target directory
-- Supports multiple files copied from Linux file managers.
-- @param target_dir string Absolute path
-- @return boolean True if at least one file was copied, false otherwise
function Linux.put_files_from_clipboard(target_dir)
    --- Parse clipboard content into valid file paths
    -- @param clip string Clipboard text
    -- @return table List of absolute file paths

    local items = {}

    -- Attempt to get clipboard content
    local text_or_html = clipboard:get 'html' or clipboard:get 'text' or ''

    -- Step 1: Handle SVG content directly
    if text_or_html:match '^<svg' then
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

    -- Step 2: Handle file paths
    if text_or_html ~= '' then
        items = clipboard:get 'files' or {}
    end

    -- Fallback: wl-paste / xclip / xsel for multiple files
    if #items == 0 then
        local cmd
        if vim.fn.executable 'wl-paste' == 1 then
            cmd = 'wl-paste -n -t text/uri-list'
        elseif vim.fn.executable 'xclip' == 1 then
            cmd = 'xclip -selection clipboard -o'
        elseif vim.fn.executable 'xsel' == 1 then
            cmd = 'xsel --clipboard --output'
        end

        if cmd then
            vim.fn.system(cmd)
            items = clipboard:get 'files' or {}
        end
    end

    if #items == 0 then
        return false
    end

    -- Copy all files/directories to target_dir
    for _, f in ipairs(items) do
        local dest = target_dir .. '/' .. vim.fn.fnamemodify(f, ':t')
        if vim.fn.isdirectory(f) == 1 then
            vim.fn.system(string.format('cp -r "%s" "%s"', f, dest))
        else
            vim.fn.system(string.format('cp "%s" "%s"', f, dest))
        end
    end

    return true
end

local function extract_archive_recursive(archive_path, target_dir)
    if vim.fn.filereadable(archive_path) == 0 then
        vim.notify(
            'Archive not found: ' .. archive_path,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    -- Record files before extraction
    local before = vim.fn.glob(target_dir .. '/*', false, true)

    -- Extract archive with 7z (supports most formats)
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

    -- Recursively extract new .tar files only
    for _, f in ipairs(new_files) do
        if f:match '%.tar$' then
            local ok = extract_archive_recursive(f, target_dir)
            os.remove(f) -- remove intermediate .tar
            if not ok then
                return false
            end
        end
    end

    return true
end

function Linux:extract_files_from_clipboard(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    local clip = vim.fn.getreg '+' or ''
    clip = vim.trim(clip):gsub('^file://', '')
    clip = vim.fn.fnamemodify(clip, ':p')

    if clip == '' or vim.fn.filereadable(clip) == 0 then
        vim.notify(
            'Clipboard does not contain a valid archive file',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    local ok = extract_archive_recursive(clip, target_dir)
    if ok then
        return true
    end

    return false
end

--- Open a file or directory in the system's file browser
-- Uses `xdg-open` or `gio` if available.
-- @param path string Absolute path to file or directory
-- @return boolean True if opened successfully, false otherwise
function Linux.open_file_browser(path)
    if not path or path == '' then
        vim.notify(
            'Invalid path provided',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local stat = vim.loop.fs_stat(path)
    if not stat then
        vim.notify(
            'Path does not exist: ' .. path,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local is_file = stat.type == 'file'

    -- Candidates: { binary, supports_select_flag }
    local candidates = {
        { 'cosmic-files', true },
        { 'nautilus', true },
        { 'nemo', true },
        { 'caja', true },
        { 'dolphin', true },
        { 'spacefm', true },
        { 'thunar', false },
        { 'pcmanfm', false },
        { 'io.elementary.files', false },
        { 'krusader', false },
        { 'doublecmd', false },
        { 'xdg-open', false },
        { 'gio', false },
    }

    local browser = nil
    for _, entry in ipairs(candidates) do
        if vim.fn.executable(entry[1]) == 1 then
            browser = entry
            break
        end
    end

    if not browser then
        vim.notify(
            'No supported file browser found on this system',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local binary, supports_select = browser[1], browser[2]
    local cmd

    if supports_select and is_file then
        -- File managers that support `--select`
        if binary == 'spacefm' then
            cmd = string.format('%s --select "%s"', binary, path)
        elseif binary == 'doublecmd' then
            cmd = string.format(
                '%s /L="%s"',
                binary,
                vim.fn.fnamemodify(path, ':h')
            )
        else
            cmd = string.format('%s --select "%s"', binary, path)
        end
    else
        -- Open parent directory or directory itself
        local target_dir = is_file and vim.fn.fnamemodify(path, ':h') or path
        if binary == 'gio' then
            cmd = string.format('gio open "%s"', target_dir)
        else
            cmd = string.format('%s "%s"', binary, target_dir)
        end
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            string.format(
                'Failed to open file browser (%s): %s',
                binary,
                result
            ),
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return false
    end

    return true
end

--- Save image from clipboard into target directory (Linux)
function Linux:save_clipboard_image(target_dir)
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
            return Linux:fix_image_extension(out_path) or out_path
        end
    end

    -- Step 2: Check for HTML <img> with base64 or URL
    if text_or_html:match '^<img' then
        -- Embedded base64 <img>
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
                return Linux:fix_image_extension(out_path) or out_path
            end
        end

        -- Linked <img> URL
        local url = text_or_html:match '<img[^>]+src="(https?://[^"]+)"'
        if url then
            local out_path =
                vim.fs.joinpath(target_dir, 'clipboard_' .. timestamp .. '.png')
            local result = vim.fn.system {
                'curl',
                '-L',
                '-s',
                '-o',
                out_path,
                '-H',
                'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
                '-H',
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                url,
            }
            if
                result
                and vim.v.shell_error == 0
                and vim.fn.filereadable(out_path) == 1
            then
                vim.notify(
                    'Downloaded image from: ' .. url,
                    vim.log.levels.INFO,
                    { title = 'yank-system-ops' }
                )
                return Linux:fix_image_extension(out_path) or out_path
            end
        end
    end

    ----------------------------------------------------------------------
    -- Step 3: Fallback to bitmap (wl-paste, xclip, or xsel)
    ----------------------------------------------------------------------
    local filename = 'clipboard_image_' .. timestamp .. '.png'
    local out_path = vim.fs.joinpath(target_dir, filename)

    local cmd
    if vim.fn.executable 'wl-paste' == 1 then
        cmd =
            string.format('bash -c \'wl-paste -t image/png > "%s"\'', out_path)
    elseif vim.fn.executable 'xclip' == 1 then
        cmd = string.format(
            'bash -c \'xclip -selection clipboard -t image/png -o > "%s"\'',
            out_path
        )
    elseif vim.fn.executable 'xsel' == 1 then
        cmd = string.format(
            'bash -c \'xsel --clipboard --output --mime-type image/png > "%s"\'',
            out_path
        )
    else
        vim.notify(
            'No supported clipboard utility found (wl-paste, xclip, xsel)',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
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

    return Linux:fix_image_extension(out_path) or out_path
end

return Linux
