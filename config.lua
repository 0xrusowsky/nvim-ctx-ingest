-- Configuration handling
local M = {}

-- Default configuration
M.default = {
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
      closed = "",
      open = "",
      empty = "",
      empty_open = "",
    },
    default = "",
    selected = "✓",
    unselected = " ",
  },

  max_file_size = 10 * 1024 * 1024,

  ignore_patterns = {
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
  },

  gitignore = {
    respect = true,  -- Whether to respect .gitignore patterns
    auto_add = true,  -- Whether to automatically add output file to .gitignore
  },
  patterns = {
    include = {},  -- Patterns to explicitly include
    exclude = {},  -- Patterns to explicitly exclude (takes precedence over include)
  },

  output = {
    save_file = false,      -- Whether to save the digest file
    copy_clipboard = true,  -- Whether to copy content to clipboard
  }
}

-- Current configuration (initialized with defaults)
local current_config = vim.deepcopy(M.default)

-- Setup configuration with user options
function M.setup(user_config)
  if not user_config then return end

  -- Validate configuration
  local function validate_config(config_table)
    -- Add validation logic here if needed
    return config_table
  end

  -- Merge configurations
  current_config = vim.tbl_deep_extend("force", current_config, validate_config(user_config))
end

-- Get current configuration
function M.get()
  return current_config
end

return M
