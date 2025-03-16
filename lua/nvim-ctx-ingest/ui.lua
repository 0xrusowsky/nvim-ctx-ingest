local M = {}

local config = require("nvim-ctx-ingest.config")
local state = require("nvim-ctx-ingest.state")
local fs = require("nvim-ctx-ingest.fs")

-- Number of header lines in the UI
local HEADER_LINE_COUNT = 7

-- Get file icon
function M.get_file_icon(name, ext, type, is_expanded, has_children)
	if type == "directory" then
		if has_children then
			return is_expanded and config.get().icons.folder.open or config.get().icons.folder.closed
		else
			return is_expanded and config.get().icons.folder.empty_open or config.get().icons.folder.empty
		end
	end

	local devicons = require("nvim-web-devicons")
	local icon, icon_hl = devicons.get_icon(name, ext, { default = true })
	return icon or config.get().icons.default, icon_hl
end

-- Format size for display
function M.format_size(size)
	if not size then
		return "-"
	end
	if size < 1024 then
		return string.format("%d B", size)
	end
	if size < 1024 * 1024 then
		return string.format("%.2f KB", size / 1024)
	end
	return string.format("%.2f MB", size / (1024 * 1024))
end

-- Format time for display
function M.format_time(timestamp)
	return os.date("%Y-%m-%d %H:%M", timestamp)
end

-- Create tree lines for display
function M.create_tree_lines(node, level, lines, selections)
	local indent = string.rep("  ", level)
	local ext = vim.fn.fnamemodify(node.path, ":e")
	local has_children = node.type == "directory" and (node.children and #node.children > 0)
	local icon = M.get_file_icon(node.name, ext, node.type, node.expanded, has_children)
	local checkbox = node.ignored and " "
		or (selections[node.path] and config.get().icons.selected or config.get().icons.unselected)

	-- Fixed widths for each column
	local name_col_width = 53
	local size_col_width = 20
	local date_col_width = 23

	-- Ensure consistent icon width with 2 spaces
	local icon_space = string.rep(" ", 2)

	-- Create the name field with proper padding and consistent spacing
	local name_content = string.format("%s%s %s%s%s", indent, checkbox, icon, icon_space, node.name)

	-- Calculate the display width of the name content (accounting for Unicode characters)
	local display_width = vim.fn.strdisplaywidth(name_content)

	local name_field
	if display_width > name_col_width then
		-- Truncate based on display width
		name_field = vim.fn.strcharpart(name_content, 0, name_col_width - 1) .. "…"
	else
		-- Pad with spaces based on display width
		name_field = name_content .. string.rep(" ", name_col_width - display_width)
	end

	-- Format size with fixed width, right-aligned
	local size_str = node.size and M.format_size(node.size) or "-"
	local size_display_width = vim.fn.strdisplaywidth(size_str)
	local size_field = string.rep(" ", size_col_width - size_display_width) .. size_str

	-- Format date with fixed width, right-aligned
	local date_str = node.mtime and M.format_time(node.mtime) or "-"
	local date_display_width = vim.fn.strdisplaywidth(date_str)
	local date_field = string.rep(" ", date_col_width - date_display_width) .. date_str

	local line = {
		text = string.format("%s%s%s", name_field, size_field, date_field),
		type = node.type,
		path = node.path,
		level = level,
		selected = selections[node.path],
		ignored = node.ignored,
	}

	table.insert(lines, line)

	if node.type == "directory" and node.expanded and node.children then
		for _, child in ipairs(node.children) do
			M.create_tree_lines(child, level + 1, lines, selections)
		end
	end
end

-- Create header
function M.create_header()
	-- Match the column widths from create_tree_lines
	local name_col_width = 54
	local size_col_width = 18
	local date_col_width = 24
	local total_width = name_col_width + size_col_width + date_col_width

	-- Format patterns for display
	local include_patterns = #config.get().patterns.include > 0 and table.concat(config.get().patterns.include, ", ")
		or ""
	local exclude_patterns = #config.get().patterns.exclude > 0 and table.concat(config.get().patterns.exclude, ", ")
		or ""

	-- Calculate padding for right alignment
	local include_base = string.format("   Include patterns: %s", include_patterns)
	local exclude_base = string.format("   Exclude patterns: %s", exclude_patterns)
	local padding_include = string.rep(" ", total_width - #include_base - 18)
	local padding_exclude = string.rep(" ", total_width - #exclude_base - 18)

	local header = {
		"",
		string.format("   Directory: %s", vim.fn.getcwd()),
		string.format("%s%s(Press 'i' to add)", include_base, padding_include),
		string.format("%s%s(Press 'e' to add)", exclude_base, padding_exclude),
		"",
		string.format(
			"%-" .. name_col_width .. "s%" .. size_col_width .. "s%" .. date_col_width .. "s",
			"   Name",
			"Size",
			"Modified"
		),
		string.format("  %s", string.rep("─", name_col_width + size_col_width + date_col_width - 1)),
	}

	return header
end

-- Create the buffer for the UI
function M.setup_buffer()
	local buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "nvim-ctx-ingest")
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	-- Set keymaps
	local opts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "h", function()
		M.handle_keypress("h")
	end, opts)
	vim.keymap.set("n", "j", "j", opts)
	vim.keymap.set("n", "k", "k", opts)
	vim.keymap.set("n", "l", function()
		M.handle_keypress("l")
	end, opts)
	vim.keymap.set("n", "<CR>", function()
		require("nvim-ctx-ingest").ingest()
	end, opts)
	vim.keymap.set("n", "<Space>", function()
		M.handle_keypress(" ")
	end, opts)
	vim.keymap.set("n", "<ESC>", function()
		M.close_window()
	end, opts)
	vim.keymap.set("n", "q", function()
		M.close_window()
	end, opts)
	vim.keymap.set("n", "i", function()
		require("nvim-ctx-ingest").add_pattern("include")
	end, opts)
	vim.keymap.set("n", "e", function()
		require("nvim-ctx-ingest").add_pattern("exclude")
	end, opts)

	-- Set modifiable to false after initial setup
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	return buf
end

-- Create window for the UI
function M.create_window(buf)
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines

	local row = math.floor((editor_height - config.get().window.height) / 2)
	local col = math.floor((editor_width - config.get().window.width) / 2)

	local win_conf = {
		relative = "editor",
		width = config.get().window.width,
		height = config.get().window.height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " CTX-INGEST ",
		title_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, true, win_conf)

	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "cursorline", true)

	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	return win
end

-- Close the window
function M.close_window()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
end

-- Flag to track if rendering is in progress
local is_rendering = false

-- Render the UI
function M.render()
	if is_rendering or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	is_rendering = true

	-- Capture current cursor position if window is valid
	local cursor_pos
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		cursor_pos = vim.api.nvim_win_get_cursor(state.win)
	end

	local header = M.create_header()
	local old_lines = state.lines
	state.lines = {}
	M.create_tree_lines(state.tree, 0, state.lines, state.selected_files)

	local text_lines = {}
	for _, line in ipairs(state.lines) do
		table.insert(text_lines, line.text)
	end

	vim.api.nvim_buf_set_option(state.buf, "modifiable", true)

	-- Use a single operation to update all lines
	vim.api.nvim_buf_set_lines(state.buf, 0, HEADER_LINE_COUNT, false, header)
	vim.api.nvim_buf_set_lines(state.buf, HEADER_LINE_COUNT, HEADER_LINE_COUNT + #old_lines, false, text_lines)

	-- Batch highlight updates
	local ns_id = vim.api.nvim_create_namespace("ctx_ingest_highlights")
	vim.api.nvim_buf_clear_namespace(state.buf, ns_id, 0, -1)

	-- Prepare highlight operations in batches
	local highlights = {}
	for i, line in ipairs(state.lines) do
		local hl
		if line.ignored then
			hl = "CtxIngestIgnored"
		elseif line.selected then
			hl = "CtxIngestSelected"
		else
			hl = line.type == "directory" and "CtxIngestDirectory" or "CtxIngestFile"
		end
		table.insert(highlights, { hl = hl, line = i + HEADER_LINE_COUNT - 1, col_start = 0, col_end = -1 })
	end

	local function apply_highlights()
		local ns_id = vim.api.nvim_create_namespace("ctx_ingest_highlights")
		vim.api.nvim_buf_clear_namespace(state.buf, ns_id, 0, -1)

		for i, line in ipairs(state.lines) do
			local hl
			if line.ignored then
				hl = "CtxIngestIgnored"
			elseif line.selected then
				hl = "CtxIngestSelected"
			else
				hl = line.type == "directory" and "CtxIngestDirectory" or "CtxIngestFile"
			end
			vim.api.nvim_buf_add_highlight(state.buf, ns_id, hl, i + HEADER_LINE_COUNT - 1, 0, -1)
		end
	end

	-- Use a single scheduled operation
	vim.schedule(apply_highlights)
	vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

	-- Restore cursor position if possible
	if cursor_pos and state.win and vim.api.nvim_win_is_valid(state.win) then
		-- Ensure cursor position is within valid range
		local line_count = vim.api.nvim_buf_line_count(state.buf)
		cursor_pos[1] = math.min(cursor_pos[1], line_count)
		vim.api.nvim_win_set_cursor(state.win, cursor_pos)
	end

	is_rendering = false
end

-- Handle key presses
function M.handle_keypress(key)
	local line = vim.fn.line(".") - HEADER_LINE_COUNT -- Adjust for header lines
	if line < 1 or line > #state.lines then
		return
	end

	local current = state.lines[line]
	if not current then
		return
	end

	-- Prevent operations on ignored files
	if current.ignored and (key == " " or key == "\r") then
		vim.notify("Cannot select ignored files", vim.log.levels.WARN)
		return
	end

	if key == "h" then
		if current.type == "directory" then
			local node = state.node_cache[current.path]
			if node and node.expanded then
				fs.collapse_node(current.path)
				M.render()
			end
		end
	elseif key == "l" then
		if current.type == "directory" then
			local node = state.node_cache[current.path]
			if node and not node.expanded then
				fs.expand_node(current.path)
				M.render()
			end
		end
	elseif key == "\r" or key == " " then
		M.toggle_selection(line + HEADER_LINE_COUNT) -- Adjust back for header lines
	end
end

-- Toggle selection of an item
function M.toggle_selection(line_num)
	local line = state.lines[line_num - HEADER_LINE_COUNT] -- Adjust for header lines
	if not line or line.ignored then
		return
	end

	local new_state = not state.selected_files[line.path]
	state.selected_files[line.path] = new_state

	if line.type == "directory" then
		-- Recursively select/deselect all children in the file system
		-- This approach traverses the actual file system rather than relying on loaded nodes
		local function process_directory(dir_path, select_state)
			local handle = vim.loop.fs_scandir(dir_path)
			if not handle then
				return
			end

			while true do
				local name, type = vim.loop.fs_scandir_next(handle)
				if not name then
					break
				end

				local child_path = dir_path .. "/" .. name
				local child_node = state.node_cache[child_path]

				-- Skip ignored files/directories
				local is_ignored = false
				if child_node and child_node.ignored then
					is_ignored = true
				elseif not child_node then
					-- If node isn't in cache, check if it should be ignored
					is_ignored = fs.should_exclude(child_path) or fs.is_in_ignored_path(child_path)
				end

				if not is_ignored then
					-- For files, just update selection state
					if type == "file" then
						state.selected_files[child_path] = select_state

						-- Create a cache entry if it doesn't exist
						if not child_node then
							local info = fs.get_file_info(child_path)
							child_node = {
								name = name,
								path = child_path,
								type = "file",
								parent = state.get_node(dir_path),
								size = info and info.size or nil,
								mtime = info and info.mtime or nil,
								ignored = false,
							}
							state.node_cache[child_path] = child_node
						end
					-- For directories, update selection and recurse
					elseif type == "directory" then
						state.selected_files[child_path] = select_state

						-- Create a cache entry if it doesn't exist
						if not child_node then
							child_node = {
								name = name,
								path = child_path,
								type = "directory",
								parent = state.get_node(dir_path),
								children = {},
								loaded = false,
								expanded = false,
								ignored = false,
							}
							state.node_cache[child_path] = child_node
						end

						-- Recursively process subdirectory
						process_directory(child_path, select_state)
					end
				end
			end
		end

		-- Start recursive processing from the selected directory
		process_directory(line.path, new_state)
	end

	M.render()
end

return M
