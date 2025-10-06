--- UI helpers for yank-system-ops
-- @module yank_system_ops.ui
local M = {}

--- Briefly highlight yanked or selected lines.
-- @param bufnr number Buffer number
-- @param start_line number Starting line (0-based)
-- @param end_line number Ending line (0-based)
-- @param opts table|nil Optional configuration { hl_group = string, duration = number }
function M.flash_highlight(bufnr, start_line, end_line, opts)
    opts = opts or {}
    local hl_group = opts.hl_group or 'IncSearch'
    local duration = opts.duration or 200
    local ns = vim.api.nvim_create_namespace 'yank_system_ops_yank_flash'

    for l = start_line, end_line do
        vim.api.nvim_buf_set_extmark(bufnr, ns, l, 0, {
            end_line = l + 1,
            hl_group = hl_group,
            hl_eol = true,
        })
    end

    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, ns, start_line, end_line + 1)
    end, duration)
end

return M
