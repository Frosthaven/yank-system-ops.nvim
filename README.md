# yank-more

This plugin is still under development.

Yank More is a cross-platform plugin that enhances the yank functionality in
Neovim. It does this primarily by leveraging 7zip to generate archives and store
them in a specified directory for easy access and sharing. With this tool you
can do the following:

- Yank files or folders (as zip) to the system clipboard for pasting into other
programs (e.g. file explorer, Slack, Discord, etc.)
- Yank generated filepaths to compressed files/folders
- Yank relative and absolute file/folder paths
- Yank lines of code as a code block with syntax highlighting for pasting into
chats
- Yank lines of code with diagnostic syntax highlighting for pasting into chats
- Yank link to selected lines in a GitHub repository
- Open the current buffer's directory in your system's file explorer:
    - Windows: explorer.exe
    - MacOS: forklift.app > finder.app
    - Linux: open-xdg default

In addition, if you yanked a compressed file/folder, you can paste it into the
buffer's current directory in Neovim to move the file/folder there.

This allows for easy moving of files/folders between Neovim sessions as well as
other programs.

## Buffers Supported

|Buffer Type | Yank File/Folder Path | Yank File/Folder Zip | Paste/Extract Zip|
|------------|-----------------------|----------------------|------------------|
| Editor     | ✅                    | ✅                   | ✅               |
| Netrw      | ✅                    | ✅                   | ✅               |
| Mini.files | ✅                    | ✅                   | ✅               |
| Oil        | ❌                    | ❌                   | ❌               |
| Telescope  | ❌                    | ❌                   | ❌               |
| Filetree   | ❌                    | ❌                   | ❌               |
| Neo-tree   | ❌                    | ❌                   | ❌               |
| Nerdtree   | ❌                    | ❌                   | ❌               |

## Requirements

- You will need access to the `7z` or `7zz` binaries from terminal.
- You will need a clipboard manager installed for your OS.

See below for installing requirements on your system:

<details>
    <summary>Windows</summary>

You can install 7zip via winget:
```powershell
winget install -e --id 7zip.7zip
```

Windows has built-in clipboard management via the `clip` command.
</details>

<details>
    <summary>MacOS</summary>

You can install 7zip via Homebrew:
```bash
brew install sevenzip
```
MacOS has built-in clipboard management via the `pbcopy` and `pbpaste` commands.
</details>

<details>
    <summary>Linux</summary>

You can install 7zip via your package manager. See below for specific distros:
```bash
# Debian/Ubuntu
sudo apt install 7zip
```

```bash
# Arch
sudo pacman -S --needed 7zip
```

For Wayland, `wl-clipboard` is recommended for clipboard management. For X11,
`xclip` or `xsel` should work.
</details>

## Setup

Lazy:

```lua
return {
    'frosthaven/yank-more.nvim',
    enabled = true,
    lazy = false,
    opts = {
        storage_path = vim.fn.expand '~/Downloads', -- path to store files
        files_to_keep = 3, -- yank_more will delete older files beyond this
        debug = false,
    },
    config = function(_, opts)
        local yank_more = require 'yank_more'
        yank_more.setup(opts)

        -- Yank selected line(s) into markdown code block ---------------------
        vim.keymap.set({ 'n', 'v' }, '<leader>yc', yank_more.yank_codeblock, { desc = '[Y]ank as [C]ode block' })

        -- yank selected line(s) into markdown code block with diagnostics ----
        vim.keymap.set({ 'n', 'v' }, '<leader>yd', yank_more.yank_diagnostics, { desc = '[Y]ank [D]iagnostic code block' })

        -- yank selected line(s) as github url --------------------------------
        vim.keymap.set({ 'n', 'v' }, '<leader>yg', yank_more.yank_github_url, { desc = '[Y]ank [G]itHub URL for current line(s)' })

        -- yank current buffer as nvim zip file path --------------------------
        vim.keymap.set({ 'n', 'v' }, '<leader>yz', yank_more.yank_compressed_file, { desc = '[Y]ank as [Z]ip file' })
        
        -- extract nvim zip file path into current buffer's directory ---------
        vim.keymap.set('n', '<leader>pz', yank_more.paste_compressed_file, { desc = '[Z]ip file [P]aste' })

        -- yank current buffer into file or compressed folder for sharing -----
        vim.keymap.set({ 'n', 'v' }, '<leader>yb', yank_more.yank_file_binary, { desc = '[Y]ank as Zip [B]inary file' })
        
        -- yank file or folder full path text for current buffer --------------
        vim.keymap.set({ 'n', 'v' }, '<leader>yr', yank_more.yank_relative_path, { desc = '[Y]ank [R]elative path of file' })
        vim.keymap.set({ 'n', 'v' }, '<leader>ya', yank_more.yank_absolute_path, { desc = '[Y]ank [A]bsolute path of file' })

        -- open buffer in external file browser -------------------------------
        vim.keymap.set('n', '<leader>o', yank_more.open_buffer_in_file_manager, { desc = '[O]pen in external file browser' })

    end,
}
```
