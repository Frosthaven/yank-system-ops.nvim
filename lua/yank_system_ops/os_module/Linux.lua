-- yank_system_ops/os_module/Linux.lua
local Base = require("yank_system_ops.os_module.__base")
local Linux = Base:extend()

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
        vim.notify('xsel does not support text/uri-list — copying as plain text instead', vim.log.levels.WARN, { title = 'Keymap' })
        cmd = string.format([[bash -c 'printf "%%s" "%s" | xsel --clipboard --input']], uris_str)
    else
        vim.notify('No supported clipboard utility found (wl-copy, xclip, xsel)', vim.log.levels.WARN, { title = 'Keymap' })
        return false
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to copy file(s) to clipboard: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

function Linux.open_file_browser(path)
    local cmd
    if vim.fn.executable('xdg-open') == 1 then
        cmd = string.format('xdg-open "%s"', path)
    elseif vim.fn.executable('gio') == 1 then
        cmd = string.format('gio open "%s"', path)
    else
        vim.notify('No supported file browser opener found (xdg-open, gio)', vim.log.levels.WARN, { title = 'Keymap' })
        return false
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify('Failed to open file browser: ' .. result, vim.log.levels.ERROR, { title = 'Keymap' })
        return false
    end
    return true
end

return Linux
