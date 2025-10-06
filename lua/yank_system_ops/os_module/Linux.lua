--- Linux-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Linux environments
-- @module yank_system_ops.os_module.Linux
local Base = require("yank_system_ops.os_module.__base")
local Linux = Base:extend()

--- Copy file(s) to the system clipboard
-- Converts file paths to URI format and uses `wl-copy`, `xclip`, or `xsel`
-- to copy them to the system clipboard.
-- @param files string|table A file path or list of file paths
-- @return boolean True if copied successfully, false otherwise
function Linux.add_files_to_clipboard(files, base_dir)

    -- filter out any files that end in /. or /..
    local filtered_files = {}
    for _, f in ipairs(type(files) == "string" and { files } or files) do
        if not f:match("/%.%.$") and not f:match("/%.$") then
            table.insert(filtered_files, f)
        end
    end
    files = filtered_files

    -- Ensure base_dir is an absolute path and ends with /
    if base_dir then
        base_dir = vim.fn.fnamemodify(base_dir, ":p")
        if base_dir:sub(-1) ~= "/" then
            base_dir = base_dir .. "/"
        end
    end

    -- Normalize input to a table
    if type(files) == "string" then
        files = { files }
    elseif type(files) ~= "table" then
        vim.notify("Invalid input to add_files_to_clipboard", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local uri_list = {}

    for _, f in ipairs(files) do
        local abs_path = vim.fn.fnamemodify(f, ":p")

        -- Skip if file does not exist
        if vim.loop.fs_stat(abs_path) then
            table.insert(uri_list, "file://" .. abs_path)
        end
    end

    if #uri_list == 0 then
        vim.notify("No valid files to copy to clipboard", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local uris_str = table.concat(uri_list, "\n"):gsub('"', '\\"')

    local cmd
    if vim.fn.executable("wl-copy") == 1 then
        cmd = string.format([[bash -c 'printf "%%s" "%s" | wl-copy -t text/uri-list']], uris_str)
    elseif vim.fn.executable("xclip") == 1 then
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xclip -selection clipboard -t text/uri-list']], uris_str)
    elseif vim.fn.executable("xsel") == 1 then
        vim.notify("xsel does not support text/uri-list — copying as plain text instead", vim.log.levels.WARN, { title = "yank-system-ops" })
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xsel --clipboard --input']], uris_str)
    else
        vim.notify("No supported clipboard utility found (wl-copy, xclip, xsel)", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to copy file(s) to clipboard: " .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    return true
end

--- Put file(s) from system clipboard into target directory
-- Supports multiple files copied from Linux file managers.
-- @param target_dir string Absolute path
-- @return boolean True if at least one file was copied, false otherwise
function Linux.put_files_from_clipboard(target_dir)
    --- Parse clipboard content into valid file paths
    -- @param clip string Clipboard text
    -- @return table List of absolute file paths
    local function parse_clipboard_files(clip)
        local items = {}
        for part in clip:gmatch("[^\r\n%s]+") do
            local path = part:gsub("^file://", "")
            if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
                table.insert(items, path)
            end
        end
        return items
    end

    local items = {}

    -- Attempt to get clipboard content via vim register
    local clip = vim.fn.getreg('+') or ''
    if clip ~= '' then
        items = parse_clipboard_files(clip)
    end

    -- Fallback: wl-paste / xclip / xsel for multiple files
    if #items == 0 then
        local cmd
        if vim.fn.executable('wl-paste') == 1 then
            cmd = 'wl-paste -n -t text/uri-list'
        elseif vim.fn.executable('xclip') == 1 then
            cmd = 'xclip -selection clipboard -o'
        elseif vim.fn.executable('xsel') == 1 then
            cmd = 'xsel --clipboard --output'
        end

        if cmd then
            local output = vim.fn.system(cmd)
            items = parse_clipboard_files(output)
        end
    end

    if #items == 0 then
        vim.notify('No valid file URIs found in clipboard', vim.log.levels.WARN, { title = 'yank-system-ops' })
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
        vim.notify("Archive not found: " .. archive_path, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Record files before extraction
    local before = vim.fn.glob(target_dir .. "/*", false, true)

    -- Extract archive with 7z (supports most formats)
    local cmd = string.format('7z x -y "%s" -o"%s"', archive_path, target_dir)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Extraction failed:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Record files after extraction
    local after = vim.fn.glob(target_dir .. "/*", false, true)

    -- Determine new files created by this extraction
    local new_files = {}
    local before_set = {}
    for _, f in ipairs(before) do before_set[f] = true end
    for _, f in ipairs(after) do
        if not before_set[f] then table.insert(new_files, f) end
    end

    -- Recursively extract new .tar files only
    for _, f in ipairs(new_files) do
        if f:match("%.tar$") then
            local ok = extract_archive_recursive(f, target_dir)
            os.remove(f)  -- remove intermediate .tar
            if not ok then return false end
        end
    end

    return true
end

function Linux:extract_files_from_clipboard(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    local clip = vim.fn.getreg("+") or ""
    clip = vim.trim(clip):gsub("^file://", "")
    clip = vim.fn.fnamemodify(clip, ":p")

    if clip == "" or vim.fn.filereadable(clip) == 0 then
        vim.notify("Clipboard does not contain a valid archive file", vim.log.levels.WARN, { title = "yank-system-ops" })
        return
    end

    local ok = extract_archive_recursive(clip, target_dir)
    if ok then
        vim.notify("Archive extracted successfully into: " .. target_dir, vim.log.levels.INFO, { title = "yank-system-ops" })
    end
end

--- Open a file or directory in the system's file browser
-- Uses `xdg-open` or `gio` if available.
-- @param path string Absolute path to file or directory
-- @return boolean True if opened successfully, false otherwise
function Linux.open_file_browser(path)
    if not path or path == "" then
        vim.notify("Invalid path provided", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local stat = vim.loop.fs_stat(path)
    if not stat then
        vim.notify("Path does not exist: " .. path, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local is_file = stat.type == "file"

    -- Candidates: { binary, supports_select_flag }
    local candidates = {
        { "cosmic-files", true },
        { "nautilus", true },
        { "nemo", true },
        { "caja", true },
        { "dolphin", true },
        { "spacefm", true },
        { "thunar", false },
        { "pcmanfm", false },
        { "io.elementary.files", false },
        { "krusader", false },
        { "doublecmd", false },
        { "xdg-open", false },
        { "gio", false },
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
            "No supported file browser found on this system",
            vim.log.levels.ERROR,
            { title = "yank-system-ops" }
        )
        return false
    end

    local binary, supports_select = browser[1], browser[2]
    local cmd

    if supports_select and is_file then
        -- File managers that support `--select`
        if binary == "spacefm" then
            cmd = string.format('%s --select "%s"', binary, path)
        elseif binary == "doublecmd" then
            cmd = string.format('%s /L="%s"', binary, vim.fn.fnamemodify(path, ":h"))
        else
            cmd = string.format('%s --select "%s"', binary, path)
        end
    else
        -- Open parent directory or directory itself
        local target_dir = is_file and vim.fn.fnamemodify(path, ":h") or path
        if binary == "gio" then
            cmd = string.format('gio open "%s"', target_dir)
        else
            cmd = string.format('%s "%s"', binary, target_dir)
        end
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            string.format("Failed to open file browser (%s): %s", binary, result),
            vim.log.levels.ERROR,
            { title = "yank-system-ops" }
        )
        return false
    end

    return true
end

--- Check if clipboard contains image data (Linux)
-- @return boolean True if clipboard has image data
function Linux:clipboard_has_image()
    local cmd
    if vim.fn.executable("wl-paste") == 1 then
        cmd = [[bash -c 'wl-paste -t image/png -n >/dev/null 2>&1']]
    elseif vim.fn.executable("xclip") == 1 then
        cmd = [[bash -c 'xclip -selection clipboard -t image/png -o >/dev/null 2>&1']]
    elseif vim.fn.executable("xsel") == 1 then
        cmd = [[bash -c 'xsel --clipboard --output --mime-type image/png >/dev/null 2>&1']]
    else
        return false
    end

    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Save image from clipboard into target directory (Linux)
function Linux:save_clipboard_image(target_dir)
    target_dir = target_dir or vim.fn.getcwd()
    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found: " .. tostring(target_dir), vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    local filename = "clipboard_image_" .. os.date("%Y%m%d_%H%M%S") .. ".png"
    local out_path = target_dir .. "/" .. filename

    local cmd
    if vim.fn.executable("wl-paste") == 1 then
        cmd = string.format('bash -c \'wl-paste -t image/png > "%s"\'', out_path)
    elseif vim.fn.executable("xclip") == 1 then
        cmd = string.format('bash -c \'xclip -selection clipboard -t image/png -o > "%s"\'', out_path)
    elseif vim.fn.executable("xsel") == 1 then
        cmd = string.format('bash -c \'xsel --clipboard --output --mime-type image/png > "%s"\'', out_path)
    else
        vim.notify("No supported clipboard utility found (wl-paste, xclip, xsel)", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to save clipboard image:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    return out_path
end

return Linux
