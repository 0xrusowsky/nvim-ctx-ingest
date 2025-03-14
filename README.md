# ctx-ingest

A Neovim plugin for efficiently sharing code context with LLMs and AI coding assistants.

## Introduction

`ctx-ingest` helps easily provide just the relevant context to AI tools like Claude or ChatGPT. It addresses the common burden of sharing relevant parts of your codebase with LLMs in a structured, efficient format.

The plugin allows you to:

- Select specific files and directories that are relevant to your current task
- Generate a well-formatted digest that preserves project structure
- Quickly share this context with your AI assistant without breaking your workflow

By providing better context, you get more accurate and helpful responses while maintaining control over exactly what code you share.
By not breaking you workflow, it allows you to be more productive.

> Inspired by [gitingest](https://github.com/cyclotruc/gitingest), but customizable and local.  

## Features

 - 🧠  Optimized output for LLMs
 - 📁  Interactive file browser with directory tree visualization
 - ✅  Select individual files or entire directories for inclusion
 - 🔍  Pattern-based file filtering (include/exclude)
 - 🚫  Respects `.gitignore` patterns
 - 📊  Generates formatted digest with directory structure and file contents
 - 📋  Auto-copy results to clipboard for pasting into LLM interfaces
 - 🔄  Auto-add output files to `.gitignore` (if enabled)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/ctx-ingest",
  dependencies = {
    "nvim-web-devicons", -- required for file icons
  },
  config = function()
    require("ctx-ingest").setup({
      -- your config options here
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/ctx-ingest",
  requires = { "nvim-web-devicons" },
  config = function()
    require("ctx-ingest").setup({
      -- your config options here
    })
  end
}
```


## Usage

### Basic Usage

1. Run `:CtxIngest` to open the file browser
2. Navigate the tree with `j` and `k`
3. Expand/collapse directories with `l` and `h`
4. Select files or directories with `Space`
5. Press `Enter` to generate the digest
6. Paste the generated context into your LLM chat

### Keyboard Shortcuts

| Key       | Action                          |
|-----------|----------------------------------|
| `j`/`k`   | Navigate up/down                |
| `h`/`l`   | Collapse/expand directories     |
| `Space`   | Toggle selection                |
| `i`       | Add include pattern             |
| `e`       | Add exclude pattern             |
| `Enter`   | Generate digest                 |
| `q`/`Esc` | Close window                    |

### Including/Excluding Files

- Press `i` to add an include pattern (e.g., `.md` to include only markdown files)
- Press `e` to add an exclude pattern (e.g., `test/` to exclude test directories)

## Configuration

You can configure `ctx-ingest` by passing options to the setup function:

```lua
require("ctx-ingest").setup({
  window = {
    position = "float",
    width = 100,
    height = 40,
  },
  
  columns = {
    size = true,
    last_modified = true,
  },
  
  icons = {
    folder = {
      closed = "",
      open = "",
      empty = "",
      empty_open = "",
    },
    default = "",
    selected = "✓",
    unselected = " ",
  },
  
  max_file_size = 10 * 1024 * 1024, -- 10MB max file size
  
  ignore_patterns = {
    ".env",
    "^%.git/",
    "%.svn/",
    "%.hg/",
    "node_modules/",
    "target/",
    "dist/",
    "build/",
    "%.pyc$",
    "__pycache__/",
    "%.egg%-info/",
    "%.vscode/",
    "%.idea/",
    "%.DS_Store$",
    "%.gitignore",
    "%.lock",
    -- Add your own patterns here
  },
  
  gitignore = {
    respect = true,  -- Whether to respect .gitignore patterns
    auto_add = true, -- Whether to add output file to .gitignore
  },
  
  patterns = {
    include = {},  -- Default include patterns
    exclude = {},  -- Default exclude patterns
  },
  
  output = {
    save_file = false,      -- Whether to save digest to file
    copy_clipboard = true,  -- Whether to copy to clipboard
  }
})
```

## Output Format

The generated digest includes:

1. Summary information (directory, file count, total size)
2. Directory tree
3. List of selected files
4. Full content of each selected file with clear separation

Example:

```
Directory: /path/to/your/project
Files analyzed: 2
Total size: 0.04 MB

Directory structure:
project
├── src
│   ├── main.lua
│   └── utils.lua
├── tests
│   └── test_main.lua
└── README.md

Selected files for content inclusion:
- src/main.lua
- README.md

================================================
File: src/main.lua
================================================
local function hello()
  print("Hello, world!")
end

return {
  hello = hello
}

================================================
File: README.md
================================================
# My Project

A simple demonstration project.
```

## Contributing

Contributions are welcome! Please feel free to submit a PR

## License

MIT

