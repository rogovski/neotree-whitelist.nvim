local M = {}

M._state = {
	active = false,
	paths = {},
	subtrees = {}, -- directories whose entire subtree should be visible
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

	vim.api.nvim_create_user_command("NeotreeWhitelist", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("NeotreeWhitelist: please provide a directory argument", vim.log.levels.WARN)
			return
		end
		M.update(cmd_opts.args)
	end, { nargs = "?" })
end

-- Build the shell command to find directories matching a regex pattern.
-- fd matches against directory names by default; the find fallback uses
-- grep -E on basenames to get equivalent behaviour.
function M._build_cmd(pattern)
	if vim.fn.executable("fd") == 1 then
		return string.format("fd --type d --absolute-path %s", vim.fn.shellescape(pattern))
	else
		-- Pipe through grep -E on the basename so we get regex matching like fd
		return string.format(
			"find . -type d | while IFS= read -r d; do "
				.. "basename \"$d\" | grep -qE %s && realpath \"$d\"; "
				.. "done",
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

function M.update(pattern)
	-- Strip trailing slash for consistency
	pattern = pattern:gsub("/$", "")

	local cmd = M._build_cmd(pattern)
	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("NeotreeWhitelist: invalid pattern or command error", vim.log.levels.ERROR)
		return
	end

	local new_paths, new_subtrees = M._parse_results(result)

	M._state.paths = new_paths
	M._state.subtrees = new_subtrees
	M._state.active = true
	require("neo-tree.sources.manager").refresh("filesystem")
	vim.notify("Neo-tree whitelist updated!")
end

return M
