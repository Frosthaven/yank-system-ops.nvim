--- UI helpers for yank-system-ops
-- @module yank_system_ops.ui
local M = {}
local loader = require 'yank_system_ops.__loader'

--- Briefly highlight yanked or selected lines.
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

--- Refresh explorers and buffers after extraction or file updates.
function M.refresh_buffer_views(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local mod = loader.get_buffer_module(bufnr)
    mod.refresh_view()

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name ~= '' and vim.fn.filereadable(buf_name) == 1 then
            if vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd 'checktime'
                end)
            end
        end
    end
end

return M
