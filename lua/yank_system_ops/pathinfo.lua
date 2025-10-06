--- Path-related helpers for yank-system-ops
-- @module yank_system_ops.pathinfo
local M = {}

--- Yank relative path of current buffer
-- @param bufnr number|nil Optional buffer number
function M.yank_relative_path(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    local relpath = vim.fn.fnamemodify(filename, ':.' .. cwd)

    vim.fn.setreg('+', relpath)
    vim.notify(
        'Yanked relative path',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
end

--- Yank absolute path of current buffer
-- @param bufnr number|nil Optional buffer number
function M.yank_absolute_path(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    vim.fn.setreg('+', filename)
    vim.notify(
        'Yanked absolute path',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
end

return M
