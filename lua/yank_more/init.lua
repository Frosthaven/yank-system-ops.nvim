local M = {}

M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}

M._loaded = false

function M.setup(opts)
    if M._loaded then
        vim.notify('yank-more is already loaded!', vim.log.levels.WARN, { title = 'yank-more' })
        return
    end
    M._loaded = true

    opts = opts or {}
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})

    if M.config.debug then
        vim.notify('Setup with config:\n' .. vim.inspect(M.config), vim.log.levels.DEBUG, { title = 'yank-more' })
    end
end

return M
