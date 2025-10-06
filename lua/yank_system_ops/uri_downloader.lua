--- URI Downloader for yank-system-ops
-- Handles downloading files, detecting MIME types, and saving with correct extensions
-- @module yank_system_ops.uri_downloader

local M = {}

--- Download a URI into the target directory with automatic extension detection
-- Supports images, PDFs, ZIPs, HTML, XML, JSON, and falls back to `.bin`.
-- @param uri string URL or FTP link
-- @param target_dir string Directory to save the downloaded file
-- @return string|nil Absolute path to the downloaded file, or nil on failure
function M.download(uri, target_dir)
    if not uri or uri == '' then
        vim.notify(
            'No URI provided to download',
            vim.log.levels.WARN,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    local filename = uri:match '.+/([^/]+)$' or 'downloaded_file'
    filename = filename:gsub('%?.*$', ''):gsub('#.*$', '')
    local url_ext = filename:match '%.([^.]+)$'

    local tmpfile = vim.fn.tempname()
    local download_cmd

    if vim.fn.executable 'curl' == 1 then
        download_cmd = string.format(
            'curl -fL -A "Mozilla/5.0" -o "%s" "%s"',
            tmpfile,
            uri
        )
    elseif vim.fn.executable 'wget' == 1 then
        download_cmd = string.format('wget -q -O "%s" "%s"', tmpfile, uri)
    else
        vim.notify(
            'Neither curl nor wget is available to download the URI',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    local result = vim.fn.system(download_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify(
            'Download failed:\n' .. result,
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    -- MIME type detection
    local mime = ''
    if vim.fn.executable 'curl' == 1 then
        mime = vim.fn.system(
            string.format(
                'curl -sI "%s" | grep -i Content-Type | awk \'{print $2}\' | tr -d "\r"',
                uri
            )
        )
    elseif vim.fn.executable 'wget' == 1 then
        mime = vim.fn.system(
            string.format(
                'wget --spider --server-response "%s" 2>&1 | grep -i Content-Type | awk \'{print $2}\' | tr -d "\r"',
                uri
            )
        )
    end
    mime = vim.trim(mime or '')

    local mime_map = {
        ['image/png'] = 'png',
        ['image/jpeg'] = 'jpg',
        ['image/jpg'] = 'jpg',
        ['image/gif'] = 'gif',
        ['image/webp'] = 'webp',
        ['application/zip'] = 'zip',
        ['application/pdf'] = 'pdf',
        ['text/html'] = 'html',
        ['application/xhtml+xml'] = 'html',
        ['application/xml'] = 'xml',
        ['text/xml'] = 'xml',
        ['application/json'] = 'json',
        ['text/json'] = 'json',
        ['image/svg+xml'] = 'svg',
    }

    local ext = mime_map[mime]

    -- Content sniffing / magic numbers
    if not ext then
        local f = io.open(tmpfile, 'rb')
        if f then
            local bytes = f:read(1024) or ''
            f:close()

            local hex = bytes:gsub('.', function(c)
                return string.format('%02X', c:byte())
            end)
            local magic_map = {
                ['89504E470D0A1A0A'] = 'png',
                ['FFD8FF'] = 'jpg',
                ['47494638'] = 'gif',
                ['504B0304'] = 'zip',
                ['25504446'] = 'pdf',
                ['52494646'] = 'webp',
            }
            for sig, mx_ext in pairs(magic_map) do
                if hex:find(sig, 1, true) then
                    ext = mx_ext
                    break
                end
            end

            -- Text sniffing
            if not ext then
                if bytes:match '^%s*<svg' then
                    ext = 'svg'
                elseif bytes:match '^%s*<%?xml' then
                    ext = 'xml'
                elseif bytes:match '^%s*{' or bytes:match '^%s*%[' then
                    ext = 'json'
                elseif
                    bytes:match '^%s*<!DOCTYPE html>' or bytes:match '^%s*<html'
                then
                    ext = 'html'
                end
            end
        end
    end

    if not ext and url_ext then
        ext = url_ext
    end
    if not ext then
        ext = 'bin'
    end

    local base_name = filename:gsub('%.' .. ext .. '$', '')
    if base_name == 'downloaded_file' or base_name == '' then
        local timestamp = os.date '%Y%m%d_%H%M%S'
        filename = string.format('%s__%s.%s', base_name, timestamp, ext)
    else
        filename = base_name .. '.' .. ext
    end

    local final_path = target_dir .. '/' .. filename

    local fsrc = io.open(tmpfile, 'rb')
    if not fsrc then
        vim.notify(
            'Failed to open temp file for copying',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end
    local fdst = io.open(final_path, 'wb')
    if not fdst then
        fsrc:close()
        vim.notify(
            'Failed to create target file',
            vim.log.levels.ERROR,
            { title = 'yank-system-ops' }
        )
        return nil
    end

    fdst:write(fsrc:read '*a')
    fsrc:close()
    fdst:close()
    os.remove(tmpfile)

    return final_path
end

return M
