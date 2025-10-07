--- Path-related helpers for yank-system-ops
-- @module yank_system_ops.pathinfo
local M = {}

-- Filter out '.' and '..' from a list of items
-- @param items table List of file/directory paths
-- @return table Filtered list of items
function M.filter_recursive_items(items)
    local filtered_items = {}
    for _, f in ipairs(items) do
        local name = vim.fn.fnamemodify(f, ':t')
        if name ~= '.' and name ~= '..' then
            table.insert(filtered_items, f)
        end
    end
    return filtered_items
end

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
