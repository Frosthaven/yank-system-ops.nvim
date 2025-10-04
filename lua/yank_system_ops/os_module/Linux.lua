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
