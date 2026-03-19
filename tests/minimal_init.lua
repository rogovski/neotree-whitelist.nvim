-- Minimal init for running tests in headless neovim.
-- Downloads plenary.nvim into .tests/ if not already present.

local root = vim.fn.fnamemodify("./.tests", ":p")

local function ensure(plugin, url)
	local install_path = root .. "/" .. plugin
	if not vim.loop.fs_stat(install_path) then
		print("Installing " .. plugin .. "...")
		vim.fn.system({ "git", "clone", "--depth", "1", url, install_path })
	end
	vim.opt.runtimepath:prepend(install_path)
end

ensure("plenary.nvim", "https://github.com/nvim-lua/plenary.nvim")

-- Add the plugin itself to runtimepath
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(".", ":p"))

vim.cmd("runtime plugin/plenary.vim")
