> [!IMPORTANT]
> This plugin is still in the PROTOTYPE phase. Expect breaking changes

## 🗃️ `yank-system-ops.nvim`

### Share file(s) between other folders, projects, and applications using native file copy & paste.

Have you ever wanted to quickly copy and paste files between the web, file
explorers, chat apps, email clients, and your neovim projects? Now you can!

- [✨ Features](#-features)
- [⚡️ Requirements](#️-requirements)
- [📊 Support Matrix](#-support-matrix)
  - [Operating System Support](#operating-system-support)
  - [Buffer Type Support](#buffer-type-support)
- [🚀 Usage](#-usage)
- [❓ FAQ](#-faq)
- [📋 Roadmap](#-roadmap)

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
for pasting into other applications such as Slack, Discord, and your file
browser. See the [FAQ](#-faq) for details on what can be yanked.

```lua
{
    '<leader>yp', function()
        require('yank_system_ops').put_files_from_clipboard()
    end, desc = 'Put clipboard file(s) here',
    mode = { 'n', 'v' }
},
```

Put file(s) from your system clipboard into the current supported buffer's
directory. See the [FAQ](#-faq) for details on what can be put. 

</details>

<details>
<summary><strong>📥 Yank & Extract Archives</strong></summary>

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
for pasting into other applications such as Slack, Discord, and your file
browser.

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
<summary><strong>📂 Yank File Path</strong></summary>

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
<summary><strong>🪄 Yank Markdown Codeblocks</strong></summary>

```lua
{
    '<leader>ymc', function()
        require('yank_system_ops').yank_codeblock()
    end, desc = 'Yank line(s) as markdown code block',
    mode = { 'n', 'v' }
},
```

Yank selected line(s) into a language-tagged markdown code block for pasting
into markdown supported applications.

```lua
{
    '<leader>ymd', function()
        require('yank_system_ops').yank_diagnostics()
    end, desc = 'Yank line(s) as markdown code block w/ diagnostics',
    mode = { 'n', 'v' }
},
```

Yank selected line(s) into a language-tagged markdown code block for pasting
into markdown supported applications. Includes any diagnostic messages in the
selected lines.

</details>

<details>
<summary><strong>🧭 Yank GitHub URL</strong></summary>

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

<br>

## ⚡️ Requirements

- All Platforms:
    - Neovim 0.10+
    - [Git](https://git-scm.com/) - for GitHub URL and contextual archive naming support
    - [Curl](https://curl.se/) or [Wget](https://www.gnu.org/software/wget/) for
      putting URI(s) from the web
    - 7zip binary (either `7z` or `7zz`) for archive creation and extraction.
      MacOS users will probably want `brew install sevenzip`.

- Windows:
    - tbd
- MacOS:
    - [pngpaste](https://github.com/jcsalterego/pngpaste) for better clipboard
      image support
    - `xcode-select --install` for swift command support
- Linux:
    - Wayland:
        - [wl-clipboard](https://github.com/bugaevc/wl-clipboard) clipboard
        manager
    - X11:
        - [xclip](https://github.com/astrand/xclip) or [xsel](https://github.com/kfish/xsel)
        clipboard manager

<br>

## 📊 Support Matrix

✅️ = Supported | ❌ = Not Yet Supported | ⚠️ = Untested

`yank-system-ops.nvim` needs to interact with your operating system clipboard,
cli tools, and active neovim buffers to provide its functionality. Below is a
support matrix for various operating systems and buffer types. All listed items
are planned to be supported.

### Operating System Support

| Operating System | Yank Files | Put Files | Yank as Archive | Extract Archive | Put Web URI | Put Image | Open in File Browser |
|------------------|------------|-----------|-----------------|-----------------|-------------|-----------|----------------------|
| Windows          | ✅         | ✅        | ✅              | ⚠️              | ❌          | ❌        | ❌                   |
| MacOS            | ✅         | ✅        | ✅              | ✅              | ✅          | ✅        | ✅                   |
| Linux (Wayland)  | ✅         | ✅        | ✅              | ✅              | ✅          | ✅        | ✅                   |
| Linux (X11)      | ⚠️          | ⚠️        | ⚠️             | ⚠️              | ⚠️          | ⚠️        | ⚠️                   |

### Buffer Type Support

| Buffer Type | Supported | Notes                                                      |
|-------------|-----------|------------------------------------------------------------|
| Default     | ✅        | Operates on the open file and it's directory               |
| Netrw       | ✅        | Operates on all files and folders in the current directory |
| Mini.files  | ✅        | Operates on all files and folders in the current directory |
| Oil         | ✅        | Operates on all files and folders in the current directory |

<br>

## 🚀 Usage

Once you've installed the [⚡️ Requirements](#️-requirements), you can use the
example below to configure `yank-system-ops.nvim`:

### Lazy.nvim

```lua
return {
    'frosthaven/yank-system-ops.nvim',
    enabled = true,
    lazy = false, -- currently does not support lazy loading
    opts = {
        storage_path = vim.fn.expand '~/Downloads', -- path to store archives
        files_to_keep = 3, -- automatically delete older *.nvim.zip archives
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
        -- 📥 yank & extract archives -----------------------------------------
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
        -- 📂 yank file path --------------------------------------------------
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
        -- 🪄 yank markdown codeblocks ----------------------------------------
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
        -- 🧭 yank gitHub url -------------------------------------------------
        {
            '<leader>ygl', function()
                require('yank_system_ops').yank_github_url()
            end, desc = 'Yank current line(s) as GitHub URL',
            mode = { 'n', 'v' }
        },
        -- 🌐 open in file browser --------------------------------------------
        {
            '<leader>yo', function()
                require('yank_system_ops').open_buffer_in_file_manager()
            end, desc = 'Open current buffer in system file browser',
            mode = { 'n', 'v' }
        },

    }
}
```

<br>

## ❓ FAQ

<details>
<summary><strong>What can I yank to the clipboard?</strong></summary>


| Buffer Type        | Details |
|--------------------|---------|
| Default Buffers    | The current file is copied to the clipboard. You may also yank the current file into an archive (ending in `.nvim.zip`) which gets copied to your clipboard. This can then be pasted into other applications such as Slack, Discord, and your file browser.|
| Directory Buffers  | All files and folders in the current directory are copied to the clipboard. You may also yank all files and folders in the current directory into an archive (ending in `.nvim.zip`) which gets copied to your clipboard. These can then be pasted into other applications such as Slack, Discord, and your file browser.|
| Other Applications | Files and folders, images, svg source code, archives, and web URIs (such as from your web browser). |

</details>

<details>
<summary><strong>What can I put from the clipboard?</strong></summary>


| Source Type          | Details |
|----------------------|---------|
| System Files/Folders | Files and folders copied using `yank-system-ops.nvim` or other applications (such as your OS's native file explorer) will be pasted into the current buffer's active directory.|
| Images               | An image copied to your clipboard from other applications or screenshot tools will be saved as a `.png` file in the current buffer's active directory. If you have SVG source code in your clipboard (e.g., from Lucide Icons or Figma assets), it will be saved as a `.svg` file.|
| Web URIs             | A file will be downloaded from the web URI and saved in the current buffer's active directory. Common file types are automatically detected (see next FAQ).|
| Archives             | 7z supported archive formats can be put as files or extracted to the current buffer's active directory. |

</details>

<details>
<summary><strong>What File Types are automatically detected with Web URI puts?</strong></summary>

These are some of the supported file types that are automatically detected when
putting web URIs. If the file type cannot be detected, the file will be saved
with a `.bin` extension:

| File Type | Details |
|-----------|---------|
| Images    | `.png`, `.jpg`, `.gif`, `.webp`, `.svg` |
| Archives  | `.zip`  |
| Documents | `.pdf`  |
| Markup    | `.html`, `.xml`, `.json` |

You can [browse the download handler](https://github.com/Frosthaven/yank-system-ops.nvim/blob/main/lua/yank_system_ops/uri_downloader.lua)
to learn more.

</details>

<details>
<summary><strong>How does this add native clipboard support on multiple platforms?</strong></summary>

Each platform handles the system clipboard vastly different from one another. To
bridge this gap, `yank-system-ops.nvim` uses a combination of cli tools and
native OS commands to provide a consistent experience across platforms. Below is
a high-level overview of how each platform is supported:

- **Windows:** Relies on `powershell` commands to interact with the clipboard.
  _Note: Windows support is still being worked on._
- **MacOS:** Relies on `bash`, `osascript`, and `swift` scripts to interact
  with the clipboard.
- **Linux (Wayland):** Relies on `bash`, `wl-clipboard`, and `xclip` or `xsel`
  to interact with the clipboard.

By leveraging abstractions from these underlying tools and commands,
`yank-system-ops.nvim` can effectively interact with the system clipboard on
various operating systems, allowing users to seamlessly copy and paste files,
images, and URIs between Neovim and other applications.

In addition, `yank-system-ops.nvim` uses the `7zip` cli tool. Because it is
available on all major platforms, we can provide a consistent experience when
creating and extracting archives.

</details>

<details>
<summary><strong>Why did you make this?</strong></summary>

As a developer, I live in Neovim. The rest of the workforce does not.

I often found myself needing to quickly share files over Slack, Discord, email,
and other applications. Sometimes I'd need to point fellow developers to
specific lines in a GitHub repo. Other times I need to download project assets
from either Figma or an icon provider like Lucide Icons.

All of these tasks required me to leave Neovim, navigate to my file explorer,
and then find the file(s) I needed and do something with them like an animal.

Now I can just yank and put like a civilized human being.

</details>

<br>

## 📋 Roadmap

- [x] Initial prototype
- [ ] Complete Windows support
- [ ] Complete Linux (X11) support
- [ ] Add setup opts for notifications, archive format, naming, etc.
- [ ] Add UI for narrowing file/folder selection when yanking/archiving
- [ ] Add buffer registry for runtime addition of buffer support
- [ ] Look into supporting tree-style file explorers
