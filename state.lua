local M = {}

-- Global state
M.selected_files = {}
M.tree = nil
M.buf = nil
M.win = nil
M.lines = {}
M.cursor_line = 1
M.node_cache = {}
M.expanded_paths = {}
M.rendered_lines = {}

-- Reset state
function M.reset()
  M.selected_files = {}
  M.tree = nil
  M.lines = {}
  M.cursor_line = 1
  M.node_cache = {}
  M.expanded_paths = {}
  M.rendered_lines = {}

  -- Don't reset buf and win as they might be needed for cleanup
end

-- Cache node
function M.cache_node(node)
  M.node_cache[node.path] = node
  if node.children then
    for _, child in ipairs(node.children) do
      M.cache_node(child)
    end
  end
end

-- Get node from cache
function M.get_node(path)
  return M.node_cache[path]
end

-- Clean up node cache to save memory
function M.cleanup_node_cache()
  -- Only keep nodes that are visible or expanded
  local needed_paths = {}

  -- Mark all nodes in the current view as needed
  for _, line in ipairs(M.lines) do
    needed_paths[line.path] = true
  end

  -- Mark all expanded nodes as needed
  for path in pairs(M.expanded_paths) do
    needed_paths[path] = true
  end

  -- Mark all selected nodes as needed
  for path, selected in pairs(M.selected_files) do
    if selected then
      needed_paths[path] = true
    end
  end

  -- Mark all parent nodes as needed
  for path in pairs(needed_paths) do
    local current = path
    while current ~= vim.fn.getcwd() do
      current = vim.fn.fnamemodify(current, ":h")
      needed_paths[current] = true
    end
  end

  -- Create a new cache with only the needed nodes
  local new_cache = {}
  for path, node in pairs(M.node_cache) do
    if needed_paths[path] then
      new_cache[path] = node
    end
  end

  M.node_cache = new_cache
end

return M
