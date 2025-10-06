--- Darwin-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Darwin environments
-- @module yank_system_ops.os_module.Darwin
local Base = require('yank_system_ops.os_module.__base')
local Darwin = Base:extend()

--- Helper to quote shell arguments safely
local function shell_quote(str)
    return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function get_plugin_root()
    -- Resolve to absolute path of this Lua file
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    -- Move up to the plugin root
    return vim.fn.fnamemodify(source, ":h:h:h:h") -- adjust depth as needed
end

--- Copy a single file (or multiple files) to macOS clipboard using Swift
-- @param files string|table File path(s) to copy
-- @return boolean success
function Darwin.add_files_to_clipboard(files)
    if type(files) == "string" then
        files = { files }
    elseif type(files) ~= "table" then
        vim.notify("Invalid input to add_files_to_clipboard", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local plugin_root = get_plugin_root()
    local swift_file = plugin_root .. "/lua/yank_system_ops/os_module/Darwin_copyfiles.swift"
    if not vim.loop.fs_stat(swift_file) then
        vim.notify("Swift file not found: " .. swift_file, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Build bash command with $@ to safely handle spaces
    local cmd_tbl = { "bash", "-c", "swift \"$@\"", "dummy", swift_file }
    for _, f in ipairs(files) do
        local name = vim.fn.fnamemodify(f, ":t")  -- get basename
        if name ~= "." and name ~= ".." and vim.loop.fs_stat(f) then
            table.insert(cmd_tbl, f)  -- valid file
        end
    end

    if #cmd_tbl <= 4 then  -- only bash, -c, swift "$@", dummy, swift_file
        return false  -- nothing valid to copy
    end

    local result = vim.fn.system(cmd_tbl)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to copy files to clipboard:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    return true
end

--- Put files from clipboard into target directory using Swift helper
-- @param target_dir string Absolute path
-- @return boolean True on success, false on failure
function Darwin.put_files_from_clipboard(target_dir)
    if not target_dir or target_dir == "" then
        vim.notify("No target directory specified", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    if vim.fn.isdirectory(target_dir) == 0 then
        vim.notify("Target directory not found: " .. target_dir, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Resolve the Swift helper relative to this Lua file
    local this_path = debug.getinfo(1, "S").source
    if this_path:sub(1,1) == "@" then
        this_path = this_path:sub(2)
    end
    local plugin_root = vim.fn.fnamemodify(this_path, ":h:h:h:h") -- adjust depth as needed
    local swift_file = plugin_root .. "/lua/yank_system_ops/os_module/Darwin_pastefiles.swift"

    if not vim.loop.fs_stat(swift_file) then
        vim.notify("Swift file not found: " .. swift_file, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Build the command: swift <swift_file> <target_dir>
    local cmd = { "bash", "-c", "swift \"$@\"", "dummy", swift_file, target_dir }
    local result = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to paste from clipboard:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Report success (Swift prints the message)
    vim.notify(result:gsub("\n$", ""), vim.log.levels.INFO, { title = "yank-system-ops" })
    return true
end

--- Open a file or folder in Finder (or ForkLift)
function Darwin.open_file_browser(path)
    if not path or path == "" then
        vim.notify("No path provided to open_file_browser", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local forklift_path = "/Applications/ForkLift.app"
    local cmd

    if vim.fn.isdirectory(forklift_path) == 1 then
        cmd = string.format([[
            osascript -e 'tell application "ForkLift" to open POSIX file "%s"
                           tell application "ForkLift" to activate'
        ]], path)
    elseif vim.fn.isdirectory(path) == 1 then
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

    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

--- Check if clipboard contains image
function Darwin:clipboard_has_image()
    if vim.fn.executable("pngpaste") == 1 then
        vim.fn.system('bash -c "pngpaste -b >/dev/null 2>&1"')
        return vim.v.shell_error == 0
    else
        local script = [[
            try
                the clipboard as «class PNGf»
                return 0
            on error
                return 1
            end try
        ]]
        local result = vim.fn.system("osascript -e " .. shell_quote(script))
        return result:match("0") ~= nil
    end
end

--- Save image from clipboard
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
        cmd = string.format('osascript -e %s', shell_quote(script:format(safe_path)))
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to save clipboard image:\n" .. result, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return nil
    end

    return out_path
end

return Darwin
