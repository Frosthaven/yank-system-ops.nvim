--- Internal module loader for yank-system-ops
-- Handles dynamic resolution of OS and buffer modules.
-- @module yank_system_ops.__loader
local M = {}

--- Return the current yank_system_ops configuration
-- @return table Config table
function M.get_config()
    local ok, mod = pcall(require, 'yank_system_ops')
    if not ok or not mod or not mod.config then
        vim.notify(
            'yank_system_ops configuration is not available. '
                .. 'Make sure you have called require("yank_system_ops").setup() first.',
            vim.log.levels.ERROR,
            { title = 'yank_system_ops' }
        )
    end
    return mod.config
end

--- Load the correct OS-specific implementation.
-- @return table The OS module (Darwin, Linux, Windows, etc.)
function M.get_os_module()
    local sysname = vim.loop.os_uname().sysname
    local mod_name

    if sysname:match 'Darwin' then
        mod_name = 'yank_system_ops.os_module.Darwin'
    elseif sysname:match 'Linux' then
        mod_name = 'yank_system_ops.os_module.Linux'
    elseif sysname:match 'Windows' or sysname:match 'MINGW' then
        mod_name = 'yank_system_ops.os_module.Windows'
    else
        mod_name = 'yank_system_ops.os_module.__base'
    end

    local ok, mod = pcall(require, mod_name)
    if not ok or type(mod) ~= 'table' then
        error('Failed to load OS module: ' .. mod_name)
    end

    return mod
end

--- Load the correct buffer-specific implementation based on filetype.
-- @param bufnr number Buffer number
-- @return table The buffer module instance
function M.get_buffer_module(bufnr)
    local ft = vim.bo[bufnr or 0].filetype
    local ok, mod = pcall(require, 'yank_system_ops.buffer_module.' .. ft)
    if not ok then
        ok, mod = pcall(require, 'yank_system_ops.buffer_module.__base')
    end

    if not ok or type(mod) ~= 'table' or not mod.refresh_view then
        error(
            'No valid buffer module found for filetype: ' .. (ft or 'unknown')
        )
    end

    return mod
end

--- Get context for current buffer.
-- @param bufnr number|nil Optional buffer number
-- @return table items, string base_dir, string filetype
function M.get_buffer_context(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local mod = M.get_buffer_module(bufnr)
    local items = mod.get_files() or {}
    local base_dir = mod.get_active_dir() or vim.fn.getcwd()
    local ft = vim.bo[bufnr].filetype
    return items, base_dir, ft
end

return M
