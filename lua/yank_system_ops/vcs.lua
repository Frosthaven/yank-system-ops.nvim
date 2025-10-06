--- VCS operations (Git, GitHub, etc.)
-- @module yank_system_ops.vcs
local M = {}

local ui = require 'yank_system_ops.ui'

--- Yank a GitHub URL for the current file or visual selection.
-- Detects repo, branch, file path, and line range, then copies
-- a GitHub URL to the system clipboard.
function M.yank_github_url()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    -- Confirm inside a git repo
    local repo_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if
        not repo_root
        or repo_root == ''
        or vim.fn.isdirectory(repo_root) == 0
    then
        vim.notify(
            'Not inside a Git repository',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    -- Current branch
    local branch = vim.fn.systemlist('git rev-parse --abbrev-ref HEAD')[1]
    if not branch or branch == '' or branch == 'HEAD' then
        vim.notify(
            'Could not determine Git branch',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    -- Remote URL
    local remote_url =
        vim.fn.systemlist('git config --get remote.origin.url')[1]
    if not remote_url or remote_url == '' then
        vim.notify(
            'No Git remote found',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    -- Convert SSH to HTTPS if needed
    if remote_url:match '^git@' then
        remote_url = remote_url:gsub(':', '/')
        remote_url = remote_url:gsub('git@', 'https://')
    end
    remote_url = remote_url:gsub('%.git$', '')

    -- Get relative file path
    local relpath = vim.fn.fnamemodify(filename, ':.' .. repo_root)

    -- Detect selected lines or cursor line
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

    -- Block unpushed/uncommitted changes
    local unpushed = vim.fn.systemlist(
        string.format(
            'git log %s --not --remotes -- %s',
            branch,
            vim.fn.shellescape(relpath)
        )
    )
    local status = vim.fn.systemlist(
        string.format('git status --porcelain %s', vim.fn.shellescape(relpath))
    )

    if #unpushed > 0 or #status > 0 then
        local msg_parts = {}
        if #unpushed > 0 then
            table.insert(msg_parts, 'unpushed commits')
        end
        if #status > 0 then
            table.insert(msg_parts, 'uncommitted changes')
        end
        vim.notify(
            'Cannot copy GitHub URL: file has '
                .. table.concat(msg_parts, '/')
                .. '!',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    -- Build URL
    local url = string.format('%s/blob/%s/%s', remote_url, branch, relpath)
    url = url .. '?t=' .. os.time()

    if start_line == end_line then
        url = url .. '#L' .. start_line
    else
        url = url .. '#L' .. start_line .. '-L' .. end_line
    end

    -- Yank to system clipboard
    vim.fn.setreg('+', url)
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
        'nx',
        false
    )

    -- Flash highlight (now imported)
    ui.flash_highlight(bufnr, start_line - 1, end_line - 1)

    vim.notify(
        'Yanked GitHub URL',
        vim.log.levels.INFO,
        { title = 'yank-system-ops' }
    )
end

return M
