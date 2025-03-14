-- File system operations
local M = {}

local config = require("ctx-ingest.config")
local state = require("ctx-ingest.state")
local fs_cache = {}

-- Get file info
function M.get_file_info(path)
  -- Check cache first
  if fs_cache[path] then
    return fs_cache[path]
  end

  local stat = vim.loop.fs_stat(path)
  if not stat then
    return nil
  end

  local info = {
    size = stat.size,
    type = stat.type,
    mtime = stat.mtime.sec,
  }

  -- Store in cache
  fs_cache[path] = info
  return info
end

-- Parse .gitignore patterns
function M.parse_gitignore()
  local gitignore_path = vim.fn.getcwd() .. "/.gitignore"
  local patterns = {}

  -- Check if .gitignore exists
  if vim.fn.filereadable(gitignore_path) == 1 then
    local lines = vim.fn.readfile(gitignore_path)
    for _, line in ipairs(lines) do
      -- Skip empty lines and comments
      if line ~= "" and not line:match("^%s*#") then
        -- Convert .gitignore pattern to Lua pattern
        local pattern = line
            :gsub("^%s+", "")                    -- Remove leading whitespace
            :gsub("%s+$", "")                    -- Remove trailing whitespace
            :gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1") -- Escape special characters
            :gsub("%*%*", ".*")                  -- Convert ** to .*
            :gsub("%*", "[^/]*")                 -- Convert * to [^/]*
            :gsub("^/", "^")                     -- Convert leading / to ^
        table.insert(patterns, pattern)
      end
    end
  end

  return patterns
end

-- Add pattern to .gitignore
function M.add_to_gitignore(pattern)
  local gitignore_path = vim.fn.getcwd() .. "/.gitignore"

  -- Read existing content
  local lines = {}
  if vim.fn.filereadable(gitignore_path) == 1 then
    lines = vim.fn.readfile(gitignore_path)
  end

  -- Check if pattern already exists
  for _, line in ipairs(lines) do
    if line == pattern then
      return -- Pattern already exists
    end
  end

  -- Add pattern with a newline before if file is not empty
  if #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end
  table.insert(lines, pattern)

  -- Write back to .gitignore
  vim.fn.writefile(lines, gitignore_path)
end

-- Check if a path should be ignored
function M.should_ignore(path)
  local relative_path = vim.fn.fnamemodify(path, ":.")

  -- Check exclude patterns first
  for _, pattern in ipairs(config.get().patterns.exclude) do
    if relative_path:match(pattern) then
      return true
    end
  end

  -- Ensure path ends with / if it's a directory
  if vim.fn.isdirectory(path) == 1 and not relative_path:match("/$") then
    relative_path = relative_path .. "/"
  end

  -- Check configured ignore patterns
  for _, pattern in ipairs(config.get().ignore_patterns) do
    -- Ensure pattern ends with / if it's meant for directories
    local dir_pattern = pattern:match("/$") and pattern or pattern .. "/"
    if relative_path:match(pattern) or (vim.fn.isdirectory(path) == 1 and relative_path:match(dir_pattern)) then
      return true
    end
  end

  -- Check .gitignore patterns if enabled
  if config.get().gitignore.respect then
    local gitignore_patterns = M.parse_gitignore()
    for _, pattern in ipairs(gitignore_patterns) do
      -- Ensure pattern ends with / if it's meant for directories
      local dir_pattern = pattern:match("/$") and pattern or pattern .. "/"
      if relative_path:match(pattern) or (vim.fn.isdirectory(path) == 1 and relative_path:match(dir_pattern)) then
        return true
      end
    end
  end

  return false
end

-- Check if a path is in an ignored path
function M.is_in_ignored_path(path)
  local current = path
  while current ~= vim.fn.getcwd() do
    if M.should_ignore(current) then
      return true
    end
    current = vim.fn.fnamemodify(current, ":h")
  end
  return false
end

-- Check if a path should be excluded based on patterns
function M.should_exclude(path)
  local relative_path = vim.fn.fnamemodify(path, ":.")

  -- Check exclude patterns
  for _, pattern in ipairs(config.get().patterns.exclude) do
    if relative_path:match(pattern) then
      return true
    end
  end

  -- Check configured ignore patterns
  for _, pattern in ipairs(config.get().ignore_patterns) do
    if relative_path:match(pattern) then
      return true
    end
  end

  -- Check .gitignore patterns if enabled
  if config.get().gitignore.respect then
    local gitignore_patterns = M.parse_gitignore()
    for _, pattern in ipairs(gitignore_patterns) do
      if relative_path:match(pattern) then
        return true
      end
    end
  end

  return false
end

-- Scan directory and build tree
function M.scan_directory(path, parent, depth)
  depth = depth or 1
  local max_initial_depth = 1

  local node = {
    name = vim.fn.fnamemodify(path, ":t"),
    path = path,
    type = vim.fn.isdirectory(path) == 1 and "directory" or "file",
    parent = parent,
    expanded = state.expanded_paths[path] or false,
    loaded = false, -- Track if children have been loaded
  }

  -- Only check exclude patterns for ignored state
  node.ignored = M.should_exclude(path) or M.is_in_ignored_path(path)

  -- If there are include patterns and this is a file, check for auto-selection
  if not node.ignored and node.type == "file" and #config.get().patterns.include > 0 then
    local relative_path = vim.fn.fnamemodify(path, ":.")
    for _, pattern in ipairs(config.get().patterns.include) do
      if relative_path:match(pattern) then
        state.selected_files[path] = true
        break
      end
    end
  end

  -- Cache file info (size, modified time) to avoid repeated stat calls
  if not node.ignored then
    local info = M.get_file_info(path)
    if info then
      node.size = info.size
      node.mtime = info.mtime
    end
  end

  -- Only load children if within initial depth or if expanded
  if node.type == "directory" and (depth < max_initial_depth or node.expanded) then
    node.children = {}
    node.loaded = true

    for name, type in vim.fs.dir(path) do
      if name ~= "." and name ~= ".." then
        local child_path = path .. "/" .. name
        table.insert(node.children, M.scan_directory(child_path, node, depth + 1))
      end
    end

    table.sort(node.children, function(a, b)
      if a.type == b.type then
        return a.name < b.name
      end
      return a.type == "directory"
    end)
  end

  -- Add to node cache
  state.node_cache[node.path] = node

  return node
end

-- Expand a node and load its children
function M.expand_node(path)
  local node = state.node_cache[path]
  if not node or node.type ~= "directory" then
    return
  end

  -- Mark as expanded
  node.expanded = true
  state.expanded_paths[path] = true

  -- Load children if not already loaded
  if not node.loaded then
    node.children = {}
    node.loaded = true

    for name, type in vim.fs.dir(path) do
      if name ~= "." and name ~= ".." then
        local child_path = path .. "/" .. name
        table.insert(node.children, M.scan_directory(child_path, node, 0))
      end
    end

    table.sort(node.children, function(a, b)
      if a.type == b.type then
        return a.name < b.name
      end
      return a.type == "directory"
    end)
  end
end

-- Collapse a node
function M.collapse_node(path)
  local node = state.node_cache[path]
  if not node or node.type ~= "directory" then
    return
  end

  node.expanded = false
  state.expanded_paths[path] = nil

  -- We don't unload children, just keep them in cache for later
end

-- Collect all selected files
function M.collect_selected_files()
  local result = {}
  local total = 0
  local count = 0

  -- Helper to check if a path is selected
  local function is_selected(path)
    return state.selected_files[path] == true
  end

  -- Recursively collect all selected files from the file system
  local function collect_from_dir(dir_path)
    if not is_selected(dir_path) then
      return
    end

    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local path = dir_path .. "/" .. name

      -- Skip ignored files/directories
      local is_ignored = false
      local node = state.node_cache[path]
      if node and node.ignored then
        is_ignored = true
      elseif not node then
        is_ignored = M.should_exclude(path) or M.is_in_ignored_path(path)
      end

      if not is_ignored then
        if type == "file" then
          -- Check if this file is selected directly or via a parent directory
          if is_selected(path) or is_selected(dir_path) then
            local info = M.get_file_info(path)
            local size = info and info.size or 0

            if not info or size <= config.get().max_file_size then
              table.insert(result, path)
              total = total + size
              count = count + 1
            else
              vim.notify(string.format("Skipping %s: file too large", path), vim.log.levels.WARN)
            end
          end
        elseif type == "directory" then
          -- Recurse into subdirectories
          collect_from_dir(path)
        end
      end
    end
  end

  -- Start from the root directory
  collect_from_dir(vim.fn.getcwd())

  -- Also collect individually selected files that might not be in directories
  for path, selected in pairs(state.selected_files) do
    if selected then
      local node = state.node_cache[path]
      if node and node.type == "file" and not node.ignored then
        -- Check if this file is already in the results
        local already_included = false
        for _, included_path in ipairs(result) do
          if included_path == path then
            already_included = true
            break
          end
        end

        if not already_included then
          local size = node.size or 0
          if size <= config.get().max_file_size then
            table.insert(result, path)
            total = total + size
            count = count + 1
          end
        end
      end
    end
  end

  return result, total, count
end

-- Generate digest content
function M.generate_digest(selected_paths, total_size, file_count)
  local content = {}

  -- Create summary
  local summary = {
    string.format("Directory: %s", vim.fn.getcwd()),
    string.format("Files analyzed: %d", file_count),
    string.format("Total size: %.2f MB", total_size / 1024 / 1024),
    "",
  }

  for _, line in ipairs(summary) do
    table.insert(content, line)
  end

  -- Write full directory structure with ASCII lines
  table.insert(content, "Directory structure:")

  -- Helper function to print tree with ASCII lines
  local function write_tree_node(node, prefix, is_last, excluded_paths)
    if excluded_paths[node.path] then
      return
    end

    local line = prefix
    if node.parent then
      if is_last then
        line = line .. "└── "
        prefix = prefix .. "    "
      else
        line = line .. "├── "
        prefix = prefix .. "│   "
      end
    end

    -- Write the node name without icons
    line = line .. node.name
    table.insert(content, line)

    -- Process children
    if node.type == "directory" and node.children then
      for i, child in ipairs(node.children) do
        local child_is_last = (i == #node.children)
        write_tree_node(child, prefix, child_is_last, excluded_paths)
      end
    end
  end

  -- Build excluded paths lookup
  local excluded_paths = {}
  for path, node in pairs(state.node_cache) do
    if node.ignored then
      excluded_paths[path] = true
    end
  end

  -- Write the tree starting from root
  write_tree_node(state.tree, "", true, excluded_paths)
  table.insert(content, "")

  -- Debug info
  table.insert(content, "Selected files for content inclusion:")
  for _, path in ipairs(selected_paths) do
    table.insert(content, "- " .. vim.fn.fnamemodify(path, ":."))
  end
  table.insert(content, "")

  -- Write contents of all selected files
  for _, path in ipairs(selected_paths) do
    table.insert(content, string.rep("=", 48))
    table.insert(content, "File: " .. vim.fn.fnamemodify(path, ":."))
    table.insert(content, string.rep("=", 48))

    local file_content = M.read_file(path)
    if file_content then
      table.insert(content, file_content)

      -- Ensure there's a newline at the end of each file
      if file_content:sub(-1) ~= "\n" then
        table.insert(content, "")
      end

      table.insert(content, "")
    else
      table.insert(content, "Error: Could not read file content")
      table.insert(content, "")
    end
  end

  return table.concat(content, "\n")
end

-- Read file content
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  return content
end

-- Write file content
function M.write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(content)
  file:close()

  return true
end

return M
