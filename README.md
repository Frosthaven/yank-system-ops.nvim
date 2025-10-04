> [!IMPORTANT] 
> This plugin is still in the PROTOTYPE phase. Expect breaking changes

## 🗃️ `yank-system-ops.nvim`

### Share file(s) between other folders, projects, and applications

- [✨ Features](#-features)
- [⚡️ Requirements](#️-requirements)
- [🔍️ How It Works](#%EF%B8%8F-how-it-works)
- [📊 Support Matrix](#-support-matrix)
  - [Operating System Support](#operating-system-support)
  - [Buffer Type Support](#buffer-type-support)
- [🚀 Usage](#-usage)

---

## ✨ Features

<details>
    <summary><strong>Yank file(s) as compressed file path</strong></summary>

Yank the current buffer's file(s) as a compressed zip file path. The zip file is
created in the configured `storage_path` with the extension `.nvim.zip` and the
absolute path is then copied to your system clipboard.

You can follow this up with the "Extract compressed file(s) here" feature to
extract the contents into the current buffer's directory.

### Example keymap:

```lua
{
    '<leader>yfz', function()
        require('yank_system_ops').yank_compressed_file()
    end, desc = 'Yank file(s) as compressed file path',
    mode = { 'n', 'v' }
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
    end, desc = 'Yank file(s) to system clipboard for sharing',
    mode = { 'n', 'v' }
},
```
</details>

<details>
    <summary><strong>Extract compressed file(s) here</strong></summary>

After using the "Yank file(s) as compressed file path" feature, you can use this
to extract the contents of the zip file into the current buffer's directory.

### Example keymap:

```lua
{
    '<leader>yfe', function()
        require('yank_system_ops').extract_compressed_file()
    end, desc = 'Extract compressed file(s) here',
    mode = { 'n', 'v' }
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
    end, desc = 'Yank relative path to file(s)',
    mode = { 'n', 'v' }
},
{
    '<leader>ypa', function()
        require('yank_system_ops').yank_absolute_path()
    end, desc = 'Yank absolute path to file(s)',
    mode = { 'n', 'v' }
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
    end, desc = 'Open current buffer in file browser',
    mode = { 'n', 'v' }
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
    end, desc = 'Yank line(s) as markdown code block',
    mode = { 'n', 'v' }
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
    end, desc = 'Yank line(s) as markdown code block with diagnostics',
    mode = { 'n', 'v' }
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
    end, desc = 'Yank line(s) as github url',
    mode = { 'n', 'v' }
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
</details>

<details>
  <summary><strong>MacOS</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7zz`:
    ```bash
    brew install sevenzip
    ```
</details>

<details>
  <summary><strong>Linux (Wayland)</strong></summary>

  - [Git CLI](https://git-scm.com/downloads)
  - Archive Manager: `7z`:

    ```bash
    # Debian/Ubuntu
    sudo apt install 7zip
    ```

    ```bash
    # Arch
    sudo pacman -S --needed 7zip
    ```

  - Clipboard manager: `wl-clipboard`

    ```bash
    # Debian/Ubuntu
    sudo apt install wl-clipboard
    ```

    ```bash
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
    ```

    ```bash
    # Arch
    sudo pacman -S --needed 7zip
    ```

  - Clipboard manager: `xclip`

    ```bash
    # Debian/Ubuntu
    sudo apt install xclip
    ```

    ```bash
    # Arch
    sudo pacman -S --needed xclip
    ```

</details>

---

## 🔍️ How It Works

Expand the sections below to see how each feature works under the hood:

<details>
<summary><strong>Yank file(s) as compressed file path</strong></summary>

- Determine the current buffer type (file vs list of files)

- Compress the file(s) into a `.nvim.zip` archive using the `7z` or `7zz` binary

- Save the archive to the configured `storage_path`

- Delete older `.nvim.zip` files in the `storage_path` if the number of
`.nvim.zip` files exceeds the configured `files_to_keep`

- Copy the absolute path to the zip file to your system clipboard using the
  appropriate clipboard manager for your OS.

</details>

<details>
<summary><strong>Yank file(s) to system clipboard for sharing</strong></summary>

- Determine the current buffer type (file vs list of files)

- Compress the files into a `.nvim.zip` archive using the `7z` or `7zz` binary

- Save the archive to the configured `storage_path`

- Delete older `.nvim.zip` files in the `storage_path` if the number of
`.nvim.zip` files exceeds the configured `files_to_keep`

- Copy the compressed file to the system clipboard using the appropriate
  clipboard manager for your OS. It does this in a format that can be pasted
  into file explorers, chat programs, email clients, etc.

> - On Windows, this uses powershell's `Set-Clipboard` with the `FileDropList` format.  
> - On MacOS, this uses `osacript` to set the clipboard to a `POSIX` file.  
> - On Linux, this sets your clipboard to the `text/uri-list` mime type. 
>   
> When sharing only a single file buffer, `yank-system-ops.nvim` will opt to
> skip the archiving step and just copy the file directly to the clipboard.

</details>

<details>
<summary><strong>Extract compressed file(s) here</strong></summary>

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
> - On MacOS, this uses `osascript` to open in `Forklift` (if installed) or
>   `Finder`.  
> - On Linux, this uses `xdg-open` to open your default file manager.  

</details>

---

## 📊 Support Matrix

✅️ = Supported | ❌ = Not Supported | ⚠️ = Untested

`yank-system-ops.nvim` needs to interact with your operating system clipboard,
cli tools, and active neovim buffers to provide its functionality. Below is a
support matrix for various operating systems and buffer types. All listed items
are planned to be supported.

### Operating System Support

| Operating System | Write Archive (Path Text) | Write Archive (URI) | Read Archive (Path Text) | Read Archive (URI) | Write File (URI)    | Read File (URI)    | Open in File Explorer |
|------------------|---------------------------|---------------------|--------------------------|--------------------|---------------------|--------------------|-----------------------|
| Windows          | ⚠️                        | ⚠️                  | ⚠️                       | ❌                 | ⚠️                  | ❌                 | ⚠️                    |
| MacOS            | ✅                        | ✅                  | ✅                       | ❌                 | ✅                  | ❌                 | ✅                    |
| Linux            | ✅                        | ✅                  | ✅                       | ❌                 | ✅                  | ❌                 | ✅                    |

### Buffer Type Support

| Buffer Type | Supported |
|-------------|-----------|
| File        | ✅        |
| Netrw       | ✅        |
| Mini.files  | ✅        |
| Oil         | ❌        |

---

## 🚀 Usage

Once you've installed the [⚡️ Requirements](#️-requirements), you can use the
example below to configure `yank-system-ops.nvim`:

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
            '<leader>yfz', function()
                require('yank_system_ops').yank_compressed_file()
            end, desc = 'Yank file(s) as compressed file path',
            mode = { 'n', 'v' }
        },
        {
            '<leader>yfs', function()
                require('yank_system_ops').yank_file_sharing()
            end, desc = 'Yank file(s) to system clipboard for sharing',
            mode = { 'n', 'v' }
        },
        {
            '<leader>yfe', function()
                require('yank_system_ops').extract_compressed_file()
            end, desc = 'Extract compressed file(s) here',
            mode = { 'n', 'v' }
        },
        -- yp : yank path info ------------------------------------------------
        {
            '<leader>ypr', function()
                require('yank_system_ops').yank_relative_path()
            end, desc = 'Yank relative path to file(s)',
            mode = { 'n', 'v' }
        },
        {
            '<leader>ypa', function()
                require('yank_system_ops').yank_absolute_path()
            end, desc = 'Yank absolute path to file(s)',
            mode = { 'n', 'v' }
        },
        -- yo : open buffer in external file browser --------------------------
        {
            '<leader>yo', function()
                require('yank_system_ops').open_buffer_in_file_manager()
            end, desc = 'Open current buffer in file browser',
            mode = { 'n', 'v' }
        },
        -- ym : yank markdown code block --------------------------------------
        {
            '<leader>ymc', function()
                require('yank_system_ops').yank_codeblock()
            end, desc = 'Yank line(s) as markdown code block',
            mode = { 'n', 'v' }
        },
        {
            '<leader>ymd', function()
                require('yank_system_ops').yank_diagnostics()
            end, desc = 'Yank line(s) as markdown code block with diagnostics',
            mode = { 'n', 'v' }
        },
        -- yg : yank github url -----------------------------------------------
        {
            '<leader>ygl', function()
                require('yank_system_ops').yank_github_url()
            end, desc = 'Yank line(s) as github url',
            mode = { 'n', 'v' }
        },
    }
}
```
