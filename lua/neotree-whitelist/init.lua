local M = {}

M._state = {
	active = false,
	patterns = {}, -- ordered list of pattern strings
	paths = {}, -- merged from all patterns
	subtrees = {}, -- merged from all patterns
}

function M.setup(opts)
	opts = opts or {}

	-- Monkey-patch neo-tree's item creation to apply the whitelist filter.
	-- Called from the lazy.nvim config function, so neo-tree is guaranteed loaded.
	local file_items = require("neo-tree.sources.common.file-items")
	local original_create_item = file_items.create_item

	file_items.create_item = function(context, path, _type)
		local item = original_create_item(context, path, _type)

		if M._state.active and item then
			-- If it's a directory and not in the whitelist, hide it
			if item.type == "directory" and not M._state.paths[item.path] then
				-- Also allow the item if it lives inside a matched subtree
				local in_subtree = false
				for subtree_root, _ in pairs(M._state.subtrees) do
					if item.path:sub(1, #subtree_root + 1) == subtree_root .. "/" then
						in_subtree = true
						break
					end
				end
				if not in_subtree then
					item.filtered_by = item.filtered_by or {}
					item.filtered_by.never_show = true
				end
			end
		end

		return item
	end

	-- Visual indicator highlight group
	vim.api.nvim_set_hl(0, "NeoTreeWhitelistIndicator", { fg = "#e5c07b", bold = true })

	-- Register custom component on neo-tree's filesystem components
	local fs_components = require("neo-tree.sources.filesystem.components")
	fs_components.whitelist_indicator = function(config, node, state)
		if not M._state.active or node:get_depth() ~= 1 then
			return {}
		end
		local count = #M._state.patterns
		local label = count == 1 and string.format(" [Whitelist: %s]", M._state.patterns[1])
			or string.format(" [Whitelist: %d patterns]", count)
		return { { text = label, highlight = "NeoTreeWhitelistIndicator" } }
	end

	-- Inject whitelist_indicator into the root renderer
	pcall(function()
		local neo_tree_config = require("neo-tree").config
		local renderers = neo_tree_config
			and neo_tree_config.filesystem
			and neo_tree_config.filesystem.renderers
		if renderers and renderers.directory then
			table.insert(renderers.directory, { "whitelist_indicator" })
		end
	end)

	-- Commands
	vim.api.nvim_create_user_command("NeotreeWhitelist", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("NeotreeWhitelist: please provide a directory argument", vim.log.levels.WARN)
			return
		end
		M.update(cmd_opts.args)
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("NeotreeWhitelistAdd", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("NeotreeWhitelistAdd: please provide a pattern argument", vim.log.levels.WARN)
			return
		end
		M.add(cmd_opts.args)
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("NeotreeWhitelistRemove", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("NeotreeWhitelistRemove: please provide a pattern argument", vim.log.levels.WARN)
			return
		end
		M.remove(cmd_opts.args)
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("NeotreeWhitelistClear", function()
		M.clear()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("NeotreeWhitelistList", function()
		if #M._state.patterns == 0 then
			vim.notify("Whitelist: no active patterns", vim.log.levels.INFO)
		else
			vim.notify("Whitelist patterns:\n" .. table.concat(M._state.patterns, "\n"), vim.log.levels.INFO)
		end
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("NeotreeWhitelistShow", function()
		M.show_popup()
	end, { nargs = 0 })
end

-- Build the shell command to find directories matching a regex pattern.
-- fd matches against directory names by default; the find fallback uses
-- grep -E on basenames to get equivalent behaviour.
function M._build_cmd(pattern)
	if vim.fn.executable("fd") == 1 then
		return string.format("fd --type d --absolute-path %s", vim.fn.shellescape(pattern))
	else
		-- Pipe through grep -E on the basename so we get regex matching like fd.
		-- The trailing "true" ensures the exit code is 0 even when the last
		-- directory checked by grep doesn't match the pattern.
		return string.format(
			"find . -type d | while IFS= read -r d; do "
				.. "basename \"$d\" | grep -qE %s && realpath \"$d\"; "
				.. "done; true",
			vim.fn.shellescape(pattern)
		)
	end
end

-- Parse shell output into paths and subtrees lookup tables.
-- Returns new_paths, new_subtrees.
function M._parse_results(output)
	local new_paths = {}
	local new_subtrees = {}

	for line in output:gmatch("[^\r\n]+") do
		local path = line:gsub("/$", "") -- Strip trailing slash from fd output

		-- Mark this matched directory as a subtree root (all children are visible)
		new_subtrees[path] = true

		-- Add the path and all its parents so the tree remains navigable
		local current = path
		while current and current ~= "/" and current ~= "." do
			new_paths[current] = true
			current = vim.fn.fnamemodify(current, ":h")
		end
	end

	return new_paths, new_subtrees
end

-- Rebuild merged paths/subtrees from all patterns and refresh neo-tree.
function M._rebuild()
	local merged_paths = {}
	local merged_subtrees = {}

	for _, pattern in ipairs(M._state.patterns) do
		local cmd = M._build_cmd(pattern)
		local result = vim.fn.system(cmd)
		local new_paths, new_subtrees = M._parse_results(result)

		for p, _ in pairs(new_paths) do
			merged_paths[p] = true
		end
		for s, _ in pairs(new_subtrees) do
			merged_subtrees[s] = true
		end
	end

	M._state.paths = merged_paths
	M._state.subtrees = merged_subtrees
	M._state.active = #M._state.patterns > 0
	require("neo-tree.sources.manager").refresh("filesystem")
end

-- Add a pattern to the whitelist.
function M.add(pattern)
	pattern = pattern:gsub("/$", "")

	-- Check for duplicates
	for _, existing in ipairs(M._state.patterns) do
		if existing == pattern then
			vim.notify("NeotreeWhitelist: pattern '" .. pattern .. "' already in list", vim.log.levels.INFO)
			return
		end
	end

	table.insert(M._state.patterns, pattern)
	M._rebuild()

	if not M._state.subtrees or vim.tbl_isempty(M._state.subtrees) then
		-- Remove the pattern we just added since nothing matched
		table.remove(M._state.patterns)
		M._rebuild()
		vim.notify("NeotreeWhitelist: no directories matched '" .. pattern .. "'", vim.log.levels.WARN)
		return
	end

	vim.notify("Neo-tree whitelist updated!")
end

-- Remove a pattern from the whitelist.
function M.remove(pattern)
	pattern = pattern:gsub("/$", "")

	local found = false
	for i, existing in ipairs(M._state.patterns) do
		if existing == pattern then
			table.remove(M._state.patterns, i)
			found = true
			break
		end
	end

	if not found then
		vim.notify("NeotreeWhitelist: pattern '" .. pattern .. "' not in list", vim.log.levels.WARN)
		return
	end

	M._rebuild()
	vim.notify("Neo-tree whitelist updated!")
end

-- Clear all patterns and reset state.
function M.clear()
	M._state.patterns = {}
	M._state.paths = {}
	M._state.subtrees = {}
	M._state.active = false
	require("neo-tree.sources.manager").refresh("filesystem")
	vim.notify("Neo-tree whitelist cleared!")
end

-- Return the current list of patterns.
function M.list()
	return M._state.patterns
end

-- Backward-compatible: clear and set a single pattern.
function M.update(pattern)
	pattern = pattern:gsub("/$", "")

	M._state.patterns = {}
	M._state.paths = {}
	M._state.subtrees = {}
	M._state.active = false

	-- Use add logic but inline to preserve original notify behavior
	local cmd = M._build_cmd(pattern)
	local result = vim.fn.system(cmd)
	local new_paths, new_subtrees = M._parse_results(result)

	if vim.tbl_isempty(new_paths) then
		vim.notify("NeotreeWhitelist: no directories matched '" .. pattern .. "'", vim.log.levels.WARN)
		return
	end

	table.insert(M._state.patterns, pattern)
	M._state.paths = new_paths
	M._state.subtrees = new_subtrees
	M._state.active = true
	require("neo-tree.sources.manager").refresh("filesystem")
	vim.notify("Neo-tree whitelist updated!")
end

-- Show a popup to manage whitelist patterns (requires nui.nvim).
function M.show_popup()
	local ok, Popup = pcall(require, "nui.popup")
	if not ok then
		vim.notify("NeotreeWhitelist: nui.nvim is required for the popup UI", vim.log.levels.ERROR)
		return
	end

	local popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
			text = {
				top = " Whitelist Patterns ",
				top_align = "center",
			},
		},
		relative = "editor",
		position = {
			row = "50%",
			col = "50%",
		},
		size = {
			width = 60,
			height = 20,
		},
	})

	popup:mount()

	-- Populate buffer with current patterns
	local lines = {}
	for _, pattern in ipairs(M._state.patterns) do
		table.insert(lines, pattern)
	end
	if #lines == 0 then
		lines = { "" }
	end
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

	-- Make buffer editable
	vim.api.nvim_set_option_value("modifiable", true, { buf = popup.bufnr })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = popup.bufnr })

	local function sync_and_close()
		local buf_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
		local new_patterns = {}
		for _, line in ipairs(buf_lines) do
			local trimmed = line:match("^%s*(.-)%s*$")
			if trimmed and trimmed ~= "" then
				table.insert(new_patterns, trimmed)
			end
		end
		popup:unmount()

		M._state.patterns = new_patterns
		if #new_patterns == 0 then
			M.clear()
		else
			M._rebuild()
			vim.notify("Neo-tree whitelist updated!")
		end
	end

	-- Keymaps
	popup:map("n", "q", function()
		sync_and_close()
	end, { noremap = true })

	popup:map("n", "<Esc>", function()
		sync_and_close()
	end, { noremap = true })

	popup:map("n", "<CR>", function()
		sync_and_close()
	end, { noremap = true })
end

return M
