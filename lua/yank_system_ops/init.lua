-- Yank System Ops ------------------------------------------------------------
-------------------------------------------------------------------------------

--- Yank System Ops
-- Core functionality for yank-system-ops.nvim
-- @module yank_system_ops
local M = {}

-- Default Config -------------------------------------------------------------
-------------------------------------------------------------------------------

--- Default configuration
-- @table config
-- @field storage_path string Path to store compressed files
-- @field files_to_keep number Number of compressed files to retain
-- @field debug boolean Enable debug notifications
M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-system-ops',
    files_to_keep = 3,
    debug = false,
}

-- Setup ----------------------------------------------------------------------
-------------------------------------------------------------------------------

--- Internal flag to prevent multiple setup calls
-- @boolean
M._loaded = false

--- Setup yank-system-ops
-- Initializes module and applies configuration
-- @param opts table Optional configuration overrides
function M.setup(opts)
    -- Single Setup -----------------------------------------------------------
    ---------------------------------------------------------------------------

    if M._loaded then
        vim.notify(
            'yank-system-ops is already loaded!',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end
    M._loaded = true

    -- Extend Default Options -------------------------------------------------
    ---------------------------------------------------------------------------

    opts = opts or {}
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})

    -- Mutate Config ----------------------------------------------------------
    ---------------------------------------------------------------------------

    -- ensure storage_path ends with '/'
    if not M.config.storage_path:match '/$' then
        M.config.storage_path = M.config.storage_path .. '/'
    end

    if M.config.debug then
        vim.notify(
            'Setup with config:\n' .. vim.inspect(M.config),
            vim.log.levels.DEBUG,
            { title = 'yank-system-ops' }
        )
    end

    -- Modules ----------------------------------------------------------------
    ---------------------------------------------------------------------------

    local loader = require 'yank_system_ops.__loader'
    local vcs = require 'yank_system_ops.vcs'
    local markdown = require 'yank_system_ops.markdown'
    local pathinfo = require 'yank_system_ops.pathinfo'
    local clipboard = require 'yank_system_ops.clipboard'
    local file_manager = require 'yank_system_ops.file_manager'
    local archive = require 'yank_system_ops.archive'

    -- Exposed Features -------------------------------------------------------
    ---------------------------------------------------------------------------

    -- 🧷 yank & put file(s) ----------------------------------------

    M.yank_files_to_clipboard = function()
        local items, _ = loader.get_buffer_context()
        clipboard.yank_files(items)
    end
    M.put_files_from_clipboard = function()
        local _, target_dir = loader.get_buffer_context()
        clipboard.put_files(target_dir)
    end

    -- 📥 yank & extract archives -----------------------------------

    M.zip_files_to_clipboard = function()
        local items, base_dir, filetype = loader.get_buffer_context()
        archive.zip_files_to_clipboard(items, base_dir, filetype)
    end
    M.extract_files_from_clipboard = function()
        local _, target_dir = loader.get_buffer_context()
        archive.extract_files_from_clipboard(target_dir)
    end

    -- 📂 yank path info --------------------------------------------

    M.yank_relative_path = pathinfo.yank_relative_path
    M.yank_absolute_path = pathinfo.yank_absolute_path

    -- 🪄 yank markdown codeblocks -----------------------------------

    M.yank_codeblock = markdown.yank_codeblock
    M.yank_diagnostics = markdown.yank_diagnostics

    -- 🧭 yank gitHub url -------------------------------------------

    M.yank_github_url = vcs.yank_github_url

    -- 🌐 open in file browser --------------------------------------

    M.open_buffer_in_file_manager = file_manager.open_buffer

    -- Debug ------------------------------------------------------------------
    ---------------------------------------------------------------------------

    -- notify buffer directory on BufEnter
    if M.config.debug and false then
        vim.api.nvim_create_autocmd('BufEnter', {
            callback = function()
                buffer_module = loader.get_buffer_module()
                active_dir = buffer_module.get_active_dir()
                local items, target_dir = loader.get_buffer_context()
                vim.notify(
                    'Buffer: '
                        .. vim.api.nvim_buf_get_name(0)
                        .. '\n'
                        .. 'Items: '
                        .. vim.inspect(items)
                        .. '\n'
                        .. 'Active Dir: '
                        .. (active_dir or 'N/A'),
                    vim.log.levels.DEBUG,
                    { title = 'yank-system-ops' }
                )
            end,
        })
    end
end

return M
