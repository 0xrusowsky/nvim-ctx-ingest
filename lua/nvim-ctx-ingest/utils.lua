local M = {}

-- Safe operation wrapper
function M.safe_operation(fn, ...)
  local status, result = pcall(fn, ...)
  if not status then
    vim.notify("Error in ctx-ingest: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
  return result
end

-- Deep copy a table
function M.deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[M.deep_copy(orig_key)] = M.deep_copy(orig_value)
    end
    setmetatable(copy, M.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

-- Check if a table contains a value
function M.table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- Get all keys from a table
function M.table_keys(tbl)
  local keys = {}
  for k, _ in pairs(tbl) do
    table.insert(keys, k)
  end
  return keys
end

-- Count items in a table
function M.table_count(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

-- Trim whitespace from a string
function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Check if a file exists
function M.file_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "file"
end

-- Check if a directory exists
function M.dir_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory"
end

-- Get relative path
function M.get_relative_path(path)
  return vim.fn.fnamemodify(path, ":.")
end

-- Get file extension
function M.get_extension(path)
  return vim.fn.fnamemodify(path, ":e")
end

-- Get file name
function M.get_filename(path)
  return vim.fn.fnamemodify(path, ":t")
end

-- Get directory name
function M.get_dirname(path)
  return vim.fn.fnamemodify(path, ":h:t")
end

-- Format bytes to human-readable size
function M.format_bytes(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  end
  if bytes < 1024 * 1024 then
    return string.format("%.2f KB", bytes / 1024)
  end
  if bytes < 1024 * 1024 * 1024 then
    return string.format("%.2f MB", bytes / (1024 * 1024))
  end
  return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
end

-- Debounce function
function M.debounce(fn, ms)
  local timer = vim.loop.new_timer()
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        fn(unpack(args))
      end)
    )
  end
end

-- Throttle function
function M.throttle(fn, ms)
  local timer = vim.loop.new_timer()
  local running = false
  local pending_args = nil

  local function execute(...)
    if running then
      pending_args = { ... }
      return
    end

    running = true
    fn(...)

    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        running = false
        if pending_args then
          local args = pending_args
          pending_args = nil
          execute(unpack(args))
        end
      end)
    )
  end

  return execute
end

return M
