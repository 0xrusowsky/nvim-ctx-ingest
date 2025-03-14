-- Main entry point for the plugin
local M = {}

-- Import modules
local config = require('ctx-ingest.config')
local state = require('ctx-ingest.state')
local fs = require('ctx-ingest.fs')
local ui = require('ctx-ingest.ui')
local utils = require('ctx-ingest.utils')

-- Initialize the plugin
function M.setup(user_config)
  config.setup(user_config)
end

-- Open the ctx-ingest window
function M.open()
  state.reset()
  local buf = ui.setup_buffer()
  if not buf then return end
  
  state.buf = buf
  state.win = ui.create_window(buf)
  
  -- Set root as expanded before scanning
  local root_path = vim.fn.getcwd()
  state.expanded_paths[root_path] = true
 
  -- Initial scan with limited depth
  state.tree = fs.scan_directory(root_path)

  -- Ensure root is expanded after scanning
  state.tree.expanded = true

  ui.render()

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_set_cursor(state.win, {8, 0})
    end
  end)
end

-- Add pattern for inclusion/exclusion
function M.add_pattern(pattern_type)
  vim.ui.input({
    prompt = string.format("Add %s pattern: ", pattern_type),
  }, function(input)
    if not input or input == "" then return end
    
    -- Store current tree state
    local old_tree = state.tree
    
    -- Add the pattern to the appropriate list
    if pattern_type == "include" then
      table.insert(config.get().patterns.include, input)
    else
      table.insert(config.get().patterns.exclude, input)
    end
    
    -- Reset selections if adding an include pattern
    if pattern_type == "include" then
      state.selected_files = {}
    end
    
    -- Re-render the tree with updated patterns
    state.tree = fs.scan_directory(vim.fn.getcwd())
    
    -- If this is the first scan, expand root
    if not old_tree then
      state.tree.expanded = true
    end
    
    ui.render()
  end)
end

-- Process selected files and generate output
function M.ingest()
  local selected_count = 0
  for _, selected in pairs(state.selected_files) do
    if selected then selected_count = selected_count + 1 end
  end

  if selected_count == 0 then
    vim.notify("No files selected for ingestion", vim.log.levels.WARN)
    return
  end

  local function process_ingestion(filename)
    -- Only add to gitignore if we're saving the file and auto_add is enabled
    if config.get().output.save_file and config.get().gitignore.auto_add then
      fs.add_to_gitignore(filename)
    end

    -- Collect selected files and generate content
    local selected_paths, total_size, file_count = fs.collect_selected_files()
    local content = fs.generate_digest(selected_paths, total_size, file_count)
    
    -- Save to file if configured
    if config.get().output.save_file then
      local success = fs.write_file(filename, content)
      if success then
        vim.notify(string.format("Files ingested successfully to %s", filename), vim.log.levels.INFO)
      else
        vim.notify("Failed to write output file", vim.log.levels.ERROR)
      end
    end
    
    -- Copy to clipboard if configured
    if config.get().output.copy_clipboard then
      vim.fn.setreg('+', content)
      vim.notify("Content copied to clipboard", vim.log.levels.INFO)
    end
    
    -- Close the window
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
  end

  -- If we're saving the file, prompt for filename
  if config.get().output.save_file then
    vim.ui.input({
      prompt = "Output filename: ",
      default = "digest.txt",
    }, function(filename)
      if not filename then return end
      process_ingestion(filename)
    end)
  else
    -- If not saving, just process with a default name (won't be used for saving)
    process_ingestion("digest.txt")
  end
end

-- Export public API
return setmetatable(M, {
  __index = function(_, key)
    -- Forward other function calls to appropriate modules
    if ui[key] then return ui[key] end
    if fs[key] then return fs[key] end
    return nil
  end
})

