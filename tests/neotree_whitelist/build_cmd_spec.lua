local M = require("neotree-whitelist")

describe("_build_cmd", function()
	it("uses fd when available", function()
		-- Temporarily override vim.fn.executable to simulate fd being present
		local orig = vim.fn.executable
		vim.fn.executable = function(name)
			if name == "fd" then
				return 1
			end
			return orig(name)
		end

		local cmd = M._build_cmd("^foo")
		assert.truthy(cmd:match("^fd "))
		assert.truthy(cmd:match("%-%-type d"))
		assert.truthy(cmd:match("%-%-absolute%-path"))

		vim.fn.executable = orig
	end)

	it("falls back to find + grep when fd is missing", function()
		local orig = vim.fn.executable
		vim.fn.executable = function()
			return 0
		end

		local cmd = M._build_cmd("^foo")
		assert.truthy(cmd:match("find"))
		assert.truthy(cmd:match("grep %-qE"))

		vim.fn.executable = orig
	end)

	it("shell-escapes the pattern", function()
		local orig = vim.fn.executable
		vim.fn.executable = function()
			return 1
		end

		local cmd = M._build_cmd("foo bar")
		-- shellescape wraps in single quotes
		assert.truthy(cmd:match("'foo bar'"))

		vim.fn.executable = orig
	end)
end)
