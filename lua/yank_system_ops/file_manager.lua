--- File Manager Operations for yank-system-ops
-- Handles opening the system file manager at the current buffer's file or directory.
-- @module yank_system_ops.file_manager

local M = {}
local loader = require 'yank_system_ops.__loader'
local os_module = loader.get_os_module()
local vim = vim -- localize for speed

--- Open the system file manager at the current buffer's file or directory.
-- If multiple files are selected, opens at the base directory.
-- If no files are selected, defaults to the current working directory.
-- @return nil
function M.open_buffer()
    local items, base_dir, _ = loader.get_buffer_context()

    -- Determine target path
    local target
    if #items == 1 then
        target = items[1]
    elseif #items > 1 then
        target = base_dir
    else
        target = base_dir
    end

    -- Validate target exists
    if not target or vim.fn.empty(target) == 1 then
        vim.notify(
            'No file or directory found',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return
    end

    local file_path = vim.fn.fnamemodify(target, ':p')

    -- Call OS-specific file manager opener
    os_module.open_file_browser(file_path)
end

return M
