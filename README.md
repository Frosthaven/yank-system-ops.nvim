<p align="center">
  <img src="./.meta/logo.png" alt="yank-system-ops Logo"/>
</p>

### Share file(s) between projects and OS applications

> [!IMPORTANT] 
> This plugin is still in the PROTOTYPE phase. Expect breaking changes!

`yank-system-ops.nvim` is a Neovim plugin that attempts to bridge the gap
between Neovim and your operating system's file management and clipboard
functionalities.

It allows you to move files and folders between Neovim directories (even across
sessions!), file explorers, chat programs, and more with it's various "yank" and
"paste" operations.

## 📑 Table of Contents

- [✨ Features](#-features)
- [⚡️ Requirements](#️-requirements)
- [📋 How It Works](#-how-it-works)
- [📊 Support Matrix](#-support-matrix)
  - [Operating Systems Supported](#operating-systems-supperted)
  - [Buffer Types Supported](#buffer-types-supported)
- [🚀 Usage](#-usage)

## ✨ Features

<details>
    <summary><strong>Yank file(s) as compressed file path</strong></summary>

Yank the current buffer's file(s) as a compressed zip file path. The zip file is
created in the configured `storage_path` with the extension `.nvim.zip` and the
absolute path is then copied to your system clipboard.

You can follow this up with the "Paste compressed file(s) here" feature to
extract the contents into the current buffer's directory.

### Example keymap:

```lua
{
    '<leader>yfc', function()
        require('yank_system_ops').yank_compressed_file()
    end, desc = 'Yank file(s) as compressed file path'
},
```
</details>

<details>
    <summary><strong>Yank file(s) to system clipboard for sharing</strong></summary>

Yanks the current buffer's file(s) into the system clipboard for pasting into
other applications (e.g., File Explorer, Finder, Discord, Slack, email clients).

### Example keymap:

```lua
{
    '<leader>yfs', function()
        require('yank_system_ops').yank_file_sharing()
    end, desc = 'Yank file(s) to system clipboard for sharing'
},
```
</details>

<details>
    <summary><strong>Paste compressed file(s) here</strong></summary>

After using the "Yank file(s) as compressed file path" feature, you can use this
to extract the contents of the zip file into the current buffer's directory.

### Example keymap:

```lua
{
    '<leader>yfp', function()
        require('yank_system_ops').paste_compressed_file()
    end, desc = 'Paste compressed file(s) here'
},
```
</details>

<details>
    <summary><strong>Yank path info</strong></summary>

Yank the absolute or cwd-relative path to the current buffer's file(s).

### Example keymaps:

```lua
{
    '<leader>ypr', function()
        require('yank_system_ops').yank_relative_path()
    end, desc = 'Yank relative path to file(s)'
},
{
    '<leader>ypa', function()
        require('yank_system_ops').yank_absolute_path()
    end, desc = 'Yank absolute path to file(s)'
},
```
</details>

<details>
    <summary><strong>Open current buffer in file browser</strong></summary>

Open the current buffer's directory in your system's file explorer. The explorer
used depends on your OS:

- **Windows**: Explorer.exe

- **MacOS**: Forklift or Finder

- **Linux**: open-xdg default

### Example keymap:

```lua
{
    '<leader>yo', function()
        require('yank_system_ops').open_buffer_in_file_manager()
    end, desc = 'Open current buffer in file browser'
},
```
</details>

<details>
    <summary><strong>Yank line(s) as markdown code block</strong></summary>

Yank selected line(s) into a language-spec markdown code block for pasting into
chats, Github, Obsidian, etc.

### Example keymap:

```lua
{
    '<leader>ymc', function()
        require('yank_system_ops').yank_codeblock()
    end, desc = 'Yank line(s) as markdown code block'
},
```

### Example output:

```lua
M.config = {
    storage_path = vim.fn.stdpath 'data' .. '/yank-more',
    files_to_keep = 3,
    debug = false,
}
```
</details>

<details>
    <summary><strong>Yank line(s) as markdown code block with diagnostics</strong></summary>

Yank selected line(s) into a language-spec markdown code block for pasting into
chats, Github, Obsidian, etc. Includes any diagnostic messages in the selected
lines.

### Example keymap:

```lua
{
    '<leader>ymd', function()
        require('yank_system_ops').yank_diagnostics()
    end, desc = 'Yank line(s) as markdown code block with diagnostics'
},
```

### Example output:

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
    <summary><strong>Yank line(s) as github url</strong></summary>

Yank a GitHub URL for the current line(s) in the current buffer. This respects
the current branch. _Note: This only works for files that are part of a
git-tracked repository and hosted on GitHub. This will also not copy URLs for
which there are pending commits/changes._

### Example keymap:

```lua
{
    '<leader>ygl', function()
        require('yank_system_ops').yank_github_url()
    end, desc = 'Yank line(s) as github url'
},
```

### Example output:

https://github.com/Frosthaven/yank-system-ops.nvim/blob/main/lua/yank_system_ops/init.lua?t=1759452837#L6-L10
</details>


## ⚡️ Requirements

In general, you will need `git`, `7z` or `7zz`, and a CLI clipboard manager
installed on your system for full functionality. See below for specific
instructions based on your OS:

<details>
  <summary><strong>Windows</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7z`:
    ```powershell
    winget install -e --id 7zip.7zip;
    ```
  - Clipboard manager: `clip` (built-in)
</details>

<details>
  <summary><strong>macOS</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7zz`:
    ```bash
    brew install sevenzip
    ```
  - Clipboard manager: `pbcopy` (built-in)
</details>

<details>
  <summary><strong>Linux (Wayland)</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7z`:
    ```bash
    # Debian/Ubuntu
    sudo apt install 7zip
    # Arch
    sudo pacman -S --needed 7zip
    ```
  - Clipboard manager: `wl-clipboard` (recommended)
    ```bash
    # Debian/Ubuntu
    sudo apt install wl-clipboard
    # Arch
    sudo pacman -S --needed wl-clipboard
    ```
</details>

<details>
  <summary><strong>Linux (X11)</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7z`:
    ```bash
    # Debian/Ubuntu
    sudo apt install 7zip
    # Arch
    sudo pacman -S --needed 7zip
    ```
  - Clipboard manager: `xclip`
    ```bash
    # Debian/Ubuntu
    sudo apt install xclip
    # Arch
    sudo pacman -S --needed xclip
    ```
</details>

---

## 📋 How It Works

<details>
<summary><strong>Yank file(s) as compressed file path</strong></summary>

- Determine the current buffer type (file vs list of files)

- Compress the file(s) into a zip archive using the `7z` or `7zz` binary, saving
  it to the configured `storage_path` with the extension `.nvim.zip`

- Copy either the path or the file itself to the system clipboard using the
  appropriate clipboard manager for your OS.

</details>

<details>
<summary><strong>Yank file(s) to system clipboard for sharing</strong></summary>

- Determine the current buffer type (file vs list of files)

- Copy the file(s) to the system clipboard using the appropriate clipboard
  manager for your OS. It does this in a format that can be pasted into file
  explorers, chat programs, email clients, etc.

> - On Windows, this uses powershell's `Set-Clipboard` with the `FileDropList` format.  
> - On MacOS, this uses `osacript` to set the clipboard to a `POSIX` file.  
> - On Linux, this uses `text/uri-list` mime type and your clipboard manager.  
>   
> When yanking only a single file buffer, `yank-system-ops.nvim` will opt to
> skip the archiving step and just copy the file directly to the clipboard.

</details>

<details>
<summary><strong>Paste compressed file(s) here</strong></summary>

- Determine the current buffer type (file vs list of files)

- Read the system clipboard to get the path to the `.nvim.zip` file

- Extract the contents of the zip file into the current buffer's directory using
  the `7z` or `7zz` binary.

</details>

<details>
<summary><strong>Open current buffer in file browser</strong></summary>

- Determine the current buffer type (file vs list of files)

- Open the current buffer's directory in your system's file explorer using the
  appropriate command for your OS.

> - On Windows, this uses `explorer.exe`.  
> - On MacOS, this uses `osascript` to open in Forklift (if installed) or Finder.  
> - On Linux, this uses `xdg-open` to open your default file manager.  

</details>

---

## 📊 Support Matrix

✅️ = Supported | ❌ = Not Supported | ⚠️ = Untested

`yank-system-ops.nvim` needs to interact with your operating system clipboard,
cli tools, and active neovim buffers to provide its functionality. Below is a
support matrix for various operating systems and buffer types. All listed items
are planned to be supported.

### Operating Systems Supperted

| OS              | File/Folder Archiving | System Clipboard Integration | Open in File Explorer |
|-----------------|-----------------------|------------------------------|-----------------------|
| Windows         | ⚠️                    | ⚠️                           | ⚠️                    |
| MacOS           | ✅                    | ✅                           | ✅                    |
| Linux (Wayland) | ✅                    | ✅                           | ✅                    |
| Linux (X11)     | ✅                    | ⚠️                           | ⚠️                    |

### Buffer Types Supported

| Buffer Type | Yank Path Text        | Yank File/Folder Zip | Paste/Extract Zip | Easy Paste Sharing |
|-------------|-----------------------|----------------------|-------------------|--------------------|
| File        | ✅                    | ✅                   | ✅                | ✅                 |
| Netrw       | ✅                    | ✅                   | ✅                | ✅                 |
| Mini.files  | ✅                    | ✅                   | ✅                | ✅                 |
| Oil         | ❌                    | ❌                   | ❌                | ❌                 |

---

## 🚀 Usage

See the example below for how to configure `yank-system-ops.nvim`:

```lua
return {
    'frosthaven/yank-system-ops.nvim',
    enabled = true,
    opts = {
        storage_path = vim.fn.expand '~/Downloads', -- path to store files
        files_to_keep = 3, -- automatically delete older *.nvim.zip files
        debug = false,
    },
    keys = {
        -- yf : yank file(s) --------------------------------------------------
        {
            '<leader>yfc', function()
                require('yank_system_ops').yank_compressed_file()
            end, desc = 'Yank file(s) as compressed file path'
        },
        {
            '<leader>yfs', function()
                require('yank_system_ops').yank_file_sharing()
            end, desc = 'Yank file(s) to system clipboard for sharing'
        },
        {
            '<leader>yfp', function()
                require('yank_system_ops').paste_compressed_file()
            end, desc = 'Paste compressed file(s) here'
        },
        -- yp : yank path info ------------------------------------------------
        {
            '<leader>ypr', function()
                require('yank_system_ops').yank_relative_path()
            end, desc = 'Yank relative path to file(s)'
        },
        {
            '<leader>ypa', function()
                require('yank_system_ops').yank_absolute_path()
            end, desc = 'Yank absolute path to file(s)'
        },
        -- yo : open buffer in external file browser --------------------------
        {
            '<leader>yo', function()
                require('yank_system_ops').open_buffer_in_file_manager()
            end, desc = 'Open current buffer in file browser'
        },
        -- ym : yank markdown code block --------------------------------------
        {
            '<leader>ymc', function()
                require('yank_system_ops').yank_codeblock()
            end, desc = 'Yank line(s) as markdown code block'
        },
        {
            '<leader>ymd', function()
                require('yank_system_ops').yank_diagnostics()
            end, desc = 'Yank line(s) as markdown code block with diagnostics'
        },
        -- yg : yank github url -----------------------------------------------
        {
            '<leader>ygl', function()
                require('yank_system_ops').yank_github_url()
            end, desc = 'Yank line(s) as github url'
        },
    }
}
```
