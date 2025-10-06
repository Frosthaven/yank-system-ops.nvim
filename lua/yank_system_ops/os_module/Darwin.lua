--- Darwin-specific OS module for yank_system_ops
-- Implements abstract methods from Base for Darwin environments
-- @module yank_system_ops.os_module.Darwin
local Base = require('yank_system_ops.os_module.__base')
local Darwin = Base:extend()

--- Helper to quote shell arguments safely
local function shell_quote(str)
    return "'" .. str:gsub("'", "'\\''") .. "'"
end

--- Find repo root by looking for .git folder upwards
local function find_repo_root(start_path)
    local path = vim.fn.fnamemodify(start_path or vim.fn.expand("<sfile>"), ":p") -- absolute path of current file
    while path ~= "/" do
        if vim.fn.isdirectory(path .. "/.git") == 1 then
            return path
        end
        path = vim.fn.fnamemodify(path, ":h") -- go up
    end
    return nil
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

    local repo_root = find_repo_root()  -- automatically uses <sfile>
    if not repo_root then
        vim.notify("Could not find repo root with .git", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local swift_file = repo_root .. "bin/copyfiles.swift"
    if not vim.loop.fs_stat(swift_file) then
        vim.notify("Swift file not found: " .. swift_file, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Build bash command with $@ to safely handle spaces
    local cmd_tbl = { "bash", "-c", "swift \"$@\"", "dummy", swift_file }
    for _, f in ipairs(files) do
        if vim.loop.fs_stat(f) then
            table.insert(cmd_tbl, f)  -- each path is a separate argument
        else
            vim.notify("File not found: " .. f, vim.log.levels.WARN, { title = "yank-system-ops" })
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

--- Put files from clipboard into target directory
-- @param target_dir string Absolute path
-- @return boolean success
function Darwin.put_files_from_clipboard(target_dir)
    if not target_dir or target_dir == "" then
        vim.notify("No target directory specified", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local repo_root = find_repo_root()
    if not repo_root then
        vim.notify("Could not find repo root with .git", vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    local swift_cli = repo_root .. "/bin/copyfiles.swift"
    if vim.loop.fs_stat(swift_cli) == nil then
        vim.notify("Swift file not found: " .. swift_cli, vim.log.levels.ERROR, { title = "yank-system-ops" })
        return false
    end

    -- Use Swift CLI to get file paths from clipboard
    local cmd = "bash -c " .. shell_quote("swift " .. shell_quote(swift_cli))
    local result = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 or result == "" then
        vim.notify("Clipboard is empty or unreadable", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    local files = {}
    for line in result:gmatch("[^\r\n]+") do
        local path = vim.fn.fnamemodify(line, ":p")
        if vim.loop.fs_stat(path) then
            table.insert(files, path)
        end
    end

    if #files == 0 then
        vim.notify("No valid file paths found in clipboard", vim.log.levels.WARN, { title = "yank-system-ops" })
        return false
    end

    for _, f in ipairs(files) do
        local cp_cmd = "bash -c " .. shell_quote("cp -R " .. shell_quote(f) .. " " .. shell_quote(target_dir .. "/"))
        vim.fn.system(cp_cmd)
    end

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
