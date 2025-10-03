# frosthaven/yank-system-ops.nvim

This plugin is still under development and is in the PROTOTYPE phase.

`frosthaven/yank-system-ops.nvim` is a Neovim plugin that attempts to bridge the
gap between Neovim and your operating system's file management and clipboard
functionalities. It allows you to move files and folders between Neovim sessions
and other OS applications through its hotkeys.


##  Supported Features

<details>
    <summary>Yank lines into markdown code block</summary>

Yank selected line(s) into a language-spec markdown code block for pasting into
chats, etc.

_Example keymap:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>yc', yank_system_ops.yank_codeblock,
    { desc = '[Y]ank as [C]ode block' }
)
```

_Example output:_

```lua
M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}
```
</details>

<details>
    <summary>Yank lines into markdown code block with diagnostics</summary>
Yank selected line(s) into a language-spec markdown code block with diagnostics
for pasting. Especially useful for pasting into LLMs.

_Example keymap:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>yd', yank_system_ops.yank_diagnostics,
    { desc = '[Y]ank [D]iagnostic code block' }
)
```

_Example output:_

Diagnostic:

`7`: Miss symbol `,` or `;` .

`7`: Undefined global `something_is_wrong_here`.

`lua/yank_system_ops/init.lua:6-11`:
```lua
M.config = {
    something_is_wrong_here
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}
```
</details>

<details>
    <summary>Yank GitHub URL for current line(s)</summary>
Yank a GitHub URL for the current line(s) in the current buffer. Requires that
there are no pending changes in the current git repository. This respects the
current branch.

_Example keymap:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>yg', yank_system_ops.yank_github_url,
    { desc = '[Y]ank [G]itHub URL for current line(s)' }
)
```

_Example output:_

https://github.com/Frosthaven/yank-system-ops.nvim/blob/main/lua/yank_system_ops/init.lua?t=1759452837#L6-L10
</details>

<details>
    <summary>Yank current buffer as zip file path</summary>
Yank the current buffer's file or folder contents as a compressed zip file path.
The zip file is created in the configured `storage_path` with the extension
`.nvim.zip` and the path is copied to your system clipboard.

You can follow this up with the next feature to paste the contents into the
current buffer's directory.

_Example keymap:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>yz', yank_system_ops.yank_compressed_file,
    { desc = '[Y]ank as [Z]ip file' }
)
```
</details>

<details>
    <summary>Paste zip file path contents into current directory</summary>
If you have used the previous feature to yank a zip file path, you can paste it
into the current buffer using this hotkey. The compressed file/folder will
be extracted into the current buffer's directory.

_Example keymap:_

```lua
vim.keymap.set(
    {'n'}, '<leader>pz', yank_system_ops.paste_compressed_file,
    { desc = '[P]aste [Z]ip file contents' }
)
```
</details>

<details>
    <summary>Yank current buffer into file or compressed folder for sharing</summary>
Yanks the current buffer's file or folder (compressed and saved) into the system
clipboard for easy sharing in other applications (e.g. file explorer, Slack,
Discord, etc.).

_Example keymap:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>ys', yank_system_ops.yank_file_binary,
    { desc = '[Y]ank as Zip for [S]haring' }
)
```
</details>

<details>
    <summary>Yank file or folder full path text for current buffer</summary>
Yank the current buffer's file or folder full path text into your system
clipboard. You can yank either the relative or absolute path.

_Example keymaps:_

```lua
vim.keymap.set(
    { 'n', 'v' }, '<leader>yr', yank_system_ops.yank_relative_path,
    { desc = '[Y]ank [R]elative path of file' }
)
vim.keymap.set(
    { 'n', 'v' }, '<leader>ya', yank_system_ops.yank_absolute_path,
    { desc = '[Y]ank [A]bsolute path of file' }
)
```
</details>

<details>
    <summary>Open buffer in external file browser</summary>
Open the current buffer's directory in your system's file explorer:
    - Windows: explorer.exe
    - MacOS: forklift.app if available or finder.app
    - Linux: open-xdg default

_Example keymap:_

```lua
vim.keymap.set(
    {'n'}, '<leader>o', yank_system_ops.open_buffer_in_file_manager,
    { desc = '[O]pen in external file browser' }
)
```
</details>

## Requirements

- You will need `git` installed and available from the terminal.
- You will need access to the `7z` or `7zz` binaries from terminal.
- You will need a clipboard manager installed for your OS.

See below for installing requirements on your system:

<details>
    <summary>Windows</summary>

You can install 7zip via winget:
```powershell
winget install -e --id 7zip.7zip;
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

## Operating Systems Supperted

| OS              | File/Folder Archiving | System Clipboard Integration | Open in File Explorer |
|-----------------|-----------------------|------------------------------|-----------------------|
| Windows         | ⚠️                    | ⚠️                           | ⚠️                    |
| MacOS           | ✅                    | ✅                           | ✅                    |
| Linux (Wayland) | ✅                    | ✅                           | ✅                    |
| Linux (X11)     | ✅                    | ⚠️                           | ⚠️                    |

## Buffer Types Supported

If a buffer type is listed here, there are plans to support it in the future.

| Buffer Type | Yank Path Text        | Yank File/Folder Zip | Paste/Extract Zip | Easy Paste Sharing |
|-------------|-----------------------|----------------------|-------------------|--------------------|
| Editor      | ✅                    | ✅                   | ✅                | ✅                 |
| Netrw       | ✅                    | ✅                   | ✅                | ✅                 |
| Mini.files  | ✅                    | ✅                   | ✅                | ✅                 |
| Oil         | ❌                    | ❌                   | ❌                | ❌                 |
| Telescope   | ❌                    | ❌                   | ❌                | ❌                 |
| Filetree    | ❌                    | ❌                   | ❌                | ❌                 |
| Neo-tree    | ❌                    | ❌                   | ❌                | ❌                 |
| Nerdtree    | ❌                    | ❌                   | ❌                | ❌                 |

## Setup

Lazy:

```lua
return {
    'frosthaven/yank-system-ops.nvim',
    enabled = true,
    lazy = false,
    opts = {
        storage_path = vim.fn.expand '~/Downloads', -- path to store files
        files_to_keep = 3, -- yank_system_ops will delete older files beyond this
        debug = false,
    },
    config = function(_, opts)
        local yank_system_ops = require 'yank_system_ops'
        yank_system_ops.setup(opts)

        -- Yank selected line(s) into markdown code block ---------------------
        vim.keymap.set(
            { 'n', 'v' }, '<leader>yc', yank_system_ops.yank_codeblock,
            { desc = '[Y]ank as [C]ode block' }
        )

        -- yank selected line(s) into markdown code block with diagnostics ----
        vim.keymap.set(
            { 'n', 'v' }, '<leader>yd', yank_system_ops.yank_diagnostics,
            { desc = '[Y]ank [D]iagnostic code block' }
        )

        -- yank selected line(s) as github url --------------------------------
        vim.keymap.set(
            { 'n', 'v' }, '<leader>yg', yank_system_ops.yank_github_url,
            { desc = '[Y]ank [G]itHub URL for current line(s)' }
        )

        -- yank current buffer as nvim zip file path --------------------------
        vim.keymap.set(
            { 'n', 'v' }, '<leader>yz', yank_system_ops.yank_compressed_file,
            { desc = '[Y]ank as [Z]ip file' }
        )
        
        -- extract nvim zip file path into current buffer's directory ---------
        vim.keymap.set(
            {'n'}, '<leader>pz', yank_system_ops.paste_compressed_file,
            { desc = '[P]aste [Z]ip file contents' }
        )

        -- yank current buffer into file or compressed folder for sharing -----
        vim.keymap.set(
            { 'n', 'v' }, '<leader>ys', yank_system_ops.yank_file_binary,
            { desc = '[Y]ank as Zip for [S]haring' }
        )
        
        -- yank file or folder full path text for current buffer --------------
        vim.keymap.set(
            { 'n', 'v' }, '<leader>yr', yank_system_ops.yank_relative_path,
            { desc = '[Y]ank [R]elative path of file' }
        )
        vim.keymap.set(
            { 'n', 'v' }, '<leader>ya', yank_system_ops.yank_absolute_path,
            { desc = '[Y]ank [A]bsolute path of file' }
        )

        -- open buffer in external file browser -------------------------------
        vim.keymap.set(
            {'n'}, '<leader>o', yank_system_ops.open_buffer_in_file_manager,
            { desc = '[O]pen in external file browser' }
        )
    end,
}
```
