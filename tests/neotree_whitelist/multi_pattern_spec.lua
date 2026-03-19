local M = require("neotree-whitelist")

-- Mock neo-tree manager to avoid external dependency
local mock_refresh_called = false
package.loaded["neo-tree.sources.manager"] = {
	refresh = function()
		mock_refresh_called = true
	end,
}

-- Mock vim.fn.system to return controlled results
local system_responses = {}
local original_system = vim.fn.system

describe("multi-pattern operations", function()
	before_each(function()
		M._state = { active = false, patterns = {}, paths = {}, subtrees = {} }
		mock_refresh_called = false
		system_responses = {}
		vim.fn.system = function(cmd)
			for pattern, response in pairs(system_responses) do
				if cmd:find(pattern, 1, true) then
					return response
				end
			end
			return ""
		end
	end)

	after_each(function()
		vim.fn.system = original_system
	end)

	describe("_rebuild", function()
		it("merges results from multiple patterns", function()
			M._state.patterns = { "foo", "bar" }
			system_responses["foo"] = "/a/b/foo\n"
			system_responses["bar"] = "/a/c/bar\n"

			M._rebuild()

			assert.is_true(M._state.active)
			assert.is_true(M._state.paths["/a/b/foo"])
			assert.is_true(M._state.paths["/a/c/bar"])
			assert.is_true(M._state.subtrees["/a/b/foo"])
			assert.is_true(M._state.subtrees["/a/c/bar"])
			-- Shared parent
			assert.is_true(M._state.paths["/a"])
			assert.is_true(mock_refresh_called)
		end)

		it("sets active false when patterns list is empty", function()
			M._state.patterns = {}
			M._rebuild()
			assert.is_false(M._state.active)
		end)
	end)

	describe("add", function()
		it("appends a new pattern and rebuilds", function()
			system_responses["src"] = "/repo/src\n"

			M.add("src")

			assert.equals(1, #M._state.patterns)
			assert.equals("src", M._state.patterns[1])
			assert.is_true(M._state.active)
		end)

		it("does not add duplicate patterns", function()
			M._state.patterns = { "src" }
			system_responses["src"] = "/repo/src\n"

			M.add("src")

			assert.equals(1, #M._state.patterns)
		end)

		it("strips trailing slash", function()
			system_responses["src"] = "/repo/src\n"

			M.add("src/")

			assert.equals("src", M._state.patterns[1])
		end)
	end)

	describe("remove", function()
		it("removes an existing pattern", function()
			M._state.patterns = { "src", "lib" }
			system_responses["src"] = "/repo/src\n"

			M.remove("lib")

			assert.equals(1, #M._state.patterns)
			assert.equals("src", M._state.patterns[1])
			assert.is_true(mock_refresh_called)
		end)

		it("is a no-op for non-existent pattern", function()
			M._state.patterns = { "src" }

			M.remove("nonexistent")

			assert.equals(1, #M._state.patterns)
		end)
	end)

	describe("clear", function()
		it("empties all state", function()
			M._state.patterns = { "src", "lib" }
			M._state.paths = { ["/a"] = true }
			M._state.subtrees = { ["/a/src"] = true }
			M._state.active = true

			M.clear()

			assert.same({}, M._state.patterns)
			assert.same({}, M._state.paths)
			assert.same({}, M._state.subtrees)
			assert.is_false(M._state.active)
			assert.is_true(mock_refresh_called)
		end)
	end)

	describe("list", function()
		it("returns the current patterns", function()
			M._state.patterns = { "foo", "bar" }
			local result = M.list()
			assert.same({ "foo", "bar" }, result)
		end)

		it("returns empty table when no patterns", function()
			assert.same({}, M.list())
		end)
	end)

	describe("update (backward compat)", function()
		it("clears previous patterns and sets a single one", function()
			M._state.patterns = { "old1", "old2" }
			system_responses["newpat"] = "/repo/newpat\n"

			M.update("newpat")

			assert.equals(1, #M._state.patterns)
			assert.equals("newpat", M._state.patterns[1])
			assert.is_true(M._state.active)
			assert.is_true(M._state.paths["/repo/newpat"])
		end)

		it("does not add pattern when nothing matches", function()
			system_responses = {} -- no matches

			M.update("nomatch")

			assert.equals(0, #M._state.patterns)
			assert.is_false(M._state.active)
		end)
	end)
end)
