> [!IMPORTANT] 
> This plugin is still in the PROTOTYPE phase. Expect breaking changes

## 🗃️ `yank-system-ops.nvim`

### Share file(s) between other folders, projects, and applications

Have you ever wanted to quickly copy and paste files between the web, file
explorers, chat apps, email clients, and your neovim projects? Now you can!

- [✨ Features](#-features)
- [⚡️ Requirements](#️-requirements)
- [📊 Support Matrix](#-support-matrix)
  - [Operating System Support](#operating-system-support)
  - [Buffer Type Support](#buffer-type-support)
  - [File Browser Support](#file-browser-support)
- [🚀 Usage](#-usage)

<br>

## ✨ Features

<details>
<summary><strong>🧷 Yank & Put File(s)</strong></summary>

```lua
{
    '<leader>yy', function()
        require('yank_system_ops').yank_files_to_clipboard()
    end, desc = 'Yank file(s) to system clipboard',
    mode = { 'n', 'v' }
},
```

Yank file(s) in the current supported buffer into your native system clipboard
for pasting into other applications (e.g., File Explorer, Finder, Discord,
Slack, email clients, etc.).

```lua
{
    '<leader>yp', function()
        require('yank_system_ops').put_files_from_clipboard()
    end, desc = 'Put clipboard file(s) here',
    mode = { 'n', 'v' }
},
```

Put file(s) from your system clipboard into the current supported buffer's
directory. This also supports:

- Putting URI(s) from the web (using `curl` or `wget`)

    - _Example: `https://example.com/image.png`_

- Putting Image data from the clipboard using your OS's clipboard manager

    - _Example: Right clicking an image in a web browser and selecting "Copy Image"_

</details>

<details>
<summary><strong>📥 Zip & Extract File(s)</strong></summary>

```lua
{
    '<leader>yz', function()
        require('yank_system_ops').zip_files_to_clipboard()
    end, desc = 'Zip file(s) to clipboard',
    mode = { 'n', 'v' }
},
```

Compress the current supported buffer's file(s) into a `.nvim.zip` archive
located in the configured `storage_path` and copy it to your system clipboard
for pasting into other applications (e.g., File Explorer, Finder, Discord,
Slack, email clients, etc.).

```lua
{
    '<leader>ye', function()
        require('yank_system_ops').extract_files_from_clipboard()
    end, desc = 'Extract clipboard file here',
    mode = { 'n', 'v' }
},
```

Extract the contents of a supported archive format from your system clipboard
into the current supported buffer's directory.

</details>

<details>
<summary><strong>📂 Path Info</strong></summary>

```lua
{
    '<leader>yr', function()
        require('yank_system_ops').yank_relative_path()
    end, desc = 'Yank relative path to file(s)',
    mode = { 'n', 'v' }
},
```

Yank the cwd-relative path to the current supported buffer's file(s).

```lua
{
    '<leader>ya', function()
        require('yank_system_ops').yank_absolute_path()
    end, desc = 'Yank absolute path to file(s)',
    mode = { 'n', 'v' }
},
```

Yank the full absolute path to the current supported buffer's file(s).

</details>

<details>
<summary><strong>🌐 Open in File Browser</strong></summary>

```lua
{
    '<leader>yo', function()
        require('yank_system_ops').open_buffer_in_file_manager()
    end, desc = 'Open current buffer in system file browser',
    mode = { 'n', 'v' }
},
```

Open the current supported buffer's file(s) in your system's file explorer. The
explorer used depends on your OS.

</details>

<details>
<summary><strong>🪄 Markdown Codeblocks</strong></summary>

```lua
{
    '<leader>ymc', function()
        require('yank_system_ops').yank_codeblock()
    end, desc = 'Yank line(s) as markdown code block',
    mode = { 'n', 'v' }
},
```

Yank selected line(s) into a language-tagged markdown code block for pasting
into other applications (e.g., File Explorer, Finder, Discord, Slack, email
clients, etc.).

```lua
{
    '<leader>ymd', function()
        require('yank_system_ops').yank_diagnostics()
    end, desc = 'Yank line(s) as markdown code block w/ diagnostics',
    mode = { 'n', 'v' }
},
```

Yank selected line(s) into a language-tagged markdown code block for pasting
into other applications. Includes any diagnostic messages in the selected lines.

</details>

<details>
<summary><strong>🧭 GitHub URL</strong></summary>

```lua
{
    '<leader>ygl', function()
        require('yank_system_ops').yank_github_url()
    end, desc = 'Yank current line(s) as GitHub URL',
    mode = { 'n', 'v' }
},
```

Yank a GitHub URL for the current line(s) in the current supported buffer. This
respects the current branch. _Note: This only works for files that are part of a
git-tracked repository and hosted on GitHub. This will also not copy URLs for
which there are pending commits/changes._

</details>

<br>

## ⚡️ Requirements

- All Platforms:
    - Neovim 0.10+
    - [Git](https://git-scm.com/) - for GitHub URL support
    - [Curl](https://curl.se/) or [Wget](https://www.gnu.org/software/wget/) for
      putting URI(s) from the web

- Windows:
    - tbd
- MacOS: 
    - [pngpaste](https://github.com/jcsalterego/pngpaste) for better clipboard
      image support
    - `xcode-select --install` for swift command support
- Linux:
    - Wayland:
        - [wl-clipboard](https://github.com/bugaevc/wl-clipboard)
    - X11:
        - [xclip](https://github.com/astrand/xclip) or [xsel](https://github.com/kfish/xsel)

<br>

## 📊 Support Matrix

✅️ = Supported | ❌ = Not Yet Supported | ⚠️ = Untested

`yank-system-ops.nvim` needs to interact with your operating system clipboard,
cli tools, and active neovim buffers to provide its functionality. Below is a
support matrix for various operating systems and buffer types. All listed items
are planned to be supported.

### Operating System Support

| Operating System | Yank Files | Put Files | Zip Files | Extract Files | Put Web URI | Put Image Data | Open in File Browser |
|------------------|------------|-----------|-----------|---------------|-------------|----------------|----------------------|
| Windows          | ⚠️         | ⚠️        | ⚠️        | ⚠️            | ⚠️          | ⚠️             | ⚠️                   |
| MacOS            | ✅         | ✅        | ✅        | ✅            | ✅          | ✅             | ✅                   | 
| Linux (Wayland)  | ✅         | ✅        | ✅        | ✅            | ✅          | ✅             | ✅                   |
| Linux (X11)      | ⚠️         | ⚠️        | ⚠️        | ⚠️            | ⚠️          | ⚠️             | ⚠️                   |

### Buffer Type Support

| Buffer Type | Supported | Notes                                                      |
|-------------|-----------|------------------------------------------------------------|
| default     | ✅        | Operates on the open file and it's directory               |
| Netrw       | ✅        | Operates on all files and folders in the current directory |
| Mini.files  | ✅        | Operates on all files and folders in the current directory |
| Oil         | ❌        | Operates on all files and folders in the current directory |

### File Browser Support

| File Browser           | Can Open Directory |
|------------------------|--------------------|
| explorer.exe (Windows) | ⚠️                 |
| ForkLift (MacOS)       | ✅                 |
| Finder (MacOS)         | ✅                 |
| cosmic-files           | ✅                 |
| nautilus               | ⚠️                 |
| nemo                   | ⚠️                 |
| caja                   | ⚠️                 |
| dolphin                | ⚠️                 |
| spacefm                | ⚠️                 |
| thunar                 | ⚠️                 |
| pcmanfm                | ⚠️                 |
| io.elementary.files    | ⚠️                 |
| krusader               | ⚠️                 |
| doublecmd              | ⚠️                 |
| xdg-open (fallback)    | ⚠️                 |
| gio (fallback)         | ⚠️                 |

<br>

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
        -- 🧷 yank & put file(s) ----------------------------------------------
        {
            '<leader>yy', function()
                require('yank_system_ops').yank_files_to_clipboard()
            end, desc = 'Yank file(s) to system clipboard',
            mode = { 'n', 'v' }
        },
        {
            '<leader>yp', function()
                require('yank_system_ops').put_files_from_clipboard()
            end, desc = 'Put clipboard file(s) here',
            mode = { 'n', 'v' }
        },
        -- 📥 Put / Extract files -------------------------------------------------
        {
            '<leader>yz', function()
                require('yank_system_ops').zip_files_to_clipboard()
            end, desc = 'Zip file(s) to clipboard',
            mode = { 'n', 'v' }
        },
        {
            '<leader>ye', function()
                require('yank_system_ops').extract_files_from_clipboard()
            end, desc = 'Extract clipboard file here',
            mode = { 'n', 'v' }
        },
        -- 📂 Path info -----------------------------------------------------------
        {
            '<leader>yr', function()
                require('yank_system_ops').yank_relative_path()
            end, desc = 'Yank relative path to file(s)',
            mode = { 'n', 'v' }
        },
        {
            '<leader>ya', function()
                require('yank_system_ops').yank_absolute_path()
            end, desc = 'Yank absolute path to file(s)',
            mode = { 'n', 'v' }
        },

        -- 🌐 Open in file browser ------------------------------------------------
        {
            '<leader>yo', function()
                require('yank_system_ops').open_buffer_in_file_manager()
            end, desc = 'Open current buffer in system file browser',
            mode = { 'n', 'v' }
        },

        -- 🪄 Markdown codeblocks -------------------------------------------------
        {
            '<leader>ymc', function()
                require('yank_system_ops').yank_codeblock()
            end, desc = 'Yank line(s) as markdown code block',
            mode = { 'n', 'v' }
        },
        {
            '<leader>ymd', function()
                require('yank_system_ops').yank_diagnostics()
            end, desc = 'Yank line(s) as markdown code block w/ diagnostics',
            mode = { 'n', 'v' }
        },

        -- 🧭 GitHub URL ----------------------------------------------------------
        {
            '<leader>ygl', function()
                require('yank_system_ops').yank_github_url()
            end, desc = 'Yank current line(s) as GitHub URL',
            mode = { 'n', 'v' }
        },
    }
}
```
