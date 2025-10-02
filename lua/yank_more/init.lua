local M = {}

local config = {
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
    config = vim.tbl_deep_extend('force', config, opts or {})

    if config.debug then
        vim.notify('Setup with config:\n' .. vim.inspect(config), vim.log.levels.DEBUG, { title = 'yank-more' })
    end
end

return M
