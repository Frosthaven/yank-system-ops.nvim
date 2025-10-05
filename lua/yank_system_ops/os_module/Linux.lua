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
function Linux.add_files_to_clipboard(files)
    if type(files) == 'string' then files = { files } end

    local uri_list = {}
    for _, f in ipairs(files) do
        local abs_path = vim.fn.fnamemodify(f, ':p')
        table.insert(uri_list, 'file://' .. abs_path)
    end
    local uris_str = table.concat(uri_list, '\n'):gsub('"', '\\"')

    local cmd
    if vim.fn.executable('wl-copy') == 1 then
        cmd = string.format([[bash -c 'printf "%%s" "%s" | wl-copy -t text/uri-list']], uris_str)
    elseif vim.fn.executable('xclip') == 1 then
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xclip -selection clipboard -t text/uri-list']], uris_str)
    elseif vim.fn.executable('xsel') == 1 then
        vim.notify(
            'xsel does not support text/uri-list — copying as plain text instead',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xsel --clipboard --input']], uris_str)
    else
        vim.notify(
            'No supported clipboard utility found (wl-copy, xclip, xsel)',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return false
    end

    local result = vim.fn.system(cmd)
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

--- Paste file(s) from the system clipboard into a target directory
-- Attempts to read `text/uri-list` data using wl-paste, xclip, or xsel.
-- Converts URIs to local file paths and copies them into the given directory.
-- @param target_dir string Absolute path to directory where files will be
-- pasted @return boolean True if paste operation succeeded, false otherwise
function Linux.paste_files_from_clipboard(target_dir)
    if not target_dir or target_dir == "" then
        vim.notify("No target directory specified", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local cmd
    if vim.fn.executable("wl-paste") == 1 then
        cmd = "wl-paste -t text/uri-list"
    elseif vim.fn.executable("xclip") == 1 then
        cmd = "xclip -o -selection clipboard -t text/uri-list"
    elseif vim.fn.executable("xsel") == 1 then
        cmd = "xsel --clipboard --output"
    else
        vim.notify("No supported clipboard reader found", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local output = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 or #output == 0 then
        vim.notify("Clipboard is empty or unreadable", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local files = {}
    for _, line in ipairs(output) do
        local path = line:gsub("^file://", "")
        if vim.loop.fs_stat(path) then
            table.insert(files, path)
        end
    end

    if #files == 0 then
        vim.notify("No valid file URIs found", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    for _, f in ipairs(files) do
        vim.fn.system(string.format('cp -R "%s" "%s/"', f, target_dir))
    end

    vim.notify("Pasted " .. #files .. " file(s) from clipboard", vim.log.levels.INFO, { title = "yank-system-ops" })
    return true
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

return Linux
