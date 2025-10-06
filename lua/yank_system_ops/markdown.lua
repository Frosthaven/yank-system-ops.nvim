--- Markdown generation helpers for yank-system-ops
-- @module yank_system_ops.markdown
local M = {}

local ui = require 'yank_system_ops.ui'

--- Yank a fenced codeblock from visual selection or current line.
-- Adds a ```lang fenced codeblock around the selection and copies to clipboard.
-- @param lang string|nil Language identifier for the codeblock (optional)
function M.yank_codeblock(lang)
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.mode()
    local start_line, end_line

    if mode:match '[vV]' then
        start_line = vim.fn.getpos('v')[2]
        end_line = vim.fn.getpos('.')[2]
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end
    else
        start_line = vim.api.nvim_win_get_cursor(0)[1]
        end_line = start_line
    end

    local lines =
        vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    local code = table.concat(lines, '\n')

    lang = lang or vim.bo.filetype or ''
    local markdown = string.format('```%s\n%s\n```', lang, code)

    vim.fn.setreg('+', markdown)
    vim.notify(
        'Yanked codeblock as Markdown',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )

    ui.flash_highlight(bufnr, start_line - 1, end_line - 1)
end

--- Yank diagnostics for the current buffer or selection as Markdown list.
-- Uses vim.diagnostic.get() and formats results as bullet points.
-- @param severity number|nil Optional vim.diagnostic.severity filter
function M.yank_diagnostics(severity)
    local bufnr = vim.api.nvim_get_current_buf()
    local diagnostics = vim.diagnostic.get(bufnr, { severity = severity })

    if vim.tbl_isempty(diagnostics) then
        vim.notify(
            'No diagnostics to yank',
            vim.log.levels.INFO,
            { title = 'yank-system-ops' }
        )
        return
    end

    local items = {}
    for _, d in ipairs(diagnostics) do
        local msg = d.message:gsub('\n', ' ')
        local sev = vim.diagnostic.severity[d.severity] or 'Info'
        local line = string.format('- **%s** (L%d): %s', sev, d.lnum + 1, msg)
        table.insert(items, line)
    end

    local markdown = table.concat(items, '\n')
    vim.fn.setreg('+', markdown)

    vim.notify(
        'Yanked diagnostics as Markdown',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
end

return M
