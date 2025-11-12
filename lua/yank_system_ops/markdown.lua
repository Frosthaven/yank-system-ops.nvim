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

    -- Determine selection range (or current line)
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

    -- Get selected lines
    local lines =
        vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    -- Attempt to get buffer's comment prefix
    local commentstring = vim.bo.commentstring or ''
    local comment_prefix = commentstring:match '^(.-)%%s'

    local markdown

    if comment_prefix and comment_prefix ~= '' then
        -- Map diagnostics by line number
        local diags_by_line = {}
        for _, d in ipairs(diagnostics) do
            local msg = d.message:gsub('\n', ' ')
            local lnum = d.lnum + 1
            diags_by_line[lnum] = diags_by_line[lnum] or {}
            table.insert(
                diags_by_line[lnum],
                string.format('@BUG (L%d): %s', lnum, msg)
            )
        end

        -- Annotate lines with diagnostics as inline comments
        local annotated = {}
        for i, line in ipairs(lines) do
            local lnum = start_line + i - 1
            if diags_by_line[lnum] then
                table.insert(
                    annotated,
                    line
                        .. ' '
                        .. comment_prefix
                        .. ' '
                        .. table.concat(diags_by_line[lnum], '; ')
                )
            else
                table.insert(annotated, line)
            end
        end

        markdown = string.format(
            '```%s\n%s\n```',
            vim.bo.filetype or '',
            table.concat(annotated, '\n')
        )
    else
        -- Fallback: keep original behavior (bullet list + code block)
        local items = {}
        for _, d in ipairs(diagnostics) do
            local msg = d.message:gsub('\n', ' ')
            local sev = vim.diagnostic.severity[d.severity] or 'Info'
            table.insert(
                items,
                string.format('- **%s** (L%d): %s', sev, d.lnum + 1, msg)
            )
        end

        local code = table.concat(lines, '\n')
        markdown = string.format(
            '%s\n\n```%s\n%s\n```',
            table.concat(items, '\n'),
            vim.bo.filetype or '',
            code
        )
    end

    vim.fn.setreg('+', markdown)
    vim.notify(
        'Yanked diagnostics + code',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
end

return M
