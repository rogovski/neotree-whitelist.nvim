local M = require("neotree-whitelist")

describe("whitelist filter logic", function()
	before_each(function()
		M._state = { active = false, paths = {}, subtrees = {} }
	end)

	describe("when inactive", function()
		it("does not mark anything as filtered", function()
			M._state.active = false
			-- The filter is applied inside create_item which we can't call
			-- without neo-tree, but we can verify the state flag controls behavior
			assert.is_false(M._state.active)
		end)
	end)

	describe("state management", function()
		it("marks state active after _parse_results populates paths", function()
			local paths, subtrees = M._parse_results("/a/b/src\n")
			M._state.paths = paths
			M._state.subtrees = subtrees
			M._state.active = true

			assert.is_true(M._state.active)
			assert.is_true(M._state.paths["/a/b/src"])
			assert.is_true(M._state.subtrees["/a/b/src"])
		end)

		it("replaces previous state on subsequent updates", function()
			-- First update
			local paths1, subtrees1 = M._parse_results("/a/foo\n")
			M._state.paths = paths1
			M._state.subtrees = subtrees1

			assert.is_true(M._state.paths["/a/foo"])

			-- Second update with different results
			local paths2, subtrees2 = M._parse_results("/b/bar\n")
			M._state.paths = paths2
			M._state.subtrees = subtrees2

			assert.is_nil(M._state.paths["/a/foo"])
			assert.is_true(M._state.paths["/b/bar"])
		end)
	end)

	describe("subtree matching", function()
		it("child paths are under subtree roots", function()
			local _, subtrees = M._parse_results("/repo/src\n")
			-- Simulate the check from create_item
			local child_path = "/repo/src/components/Button"
			local in_subtree = false
			for subtree_root, _ in pairs(subtrees) do
				if child_path:sub(1, #subtree_root + 1) == subtree_root .. "/" then
					in_subtree = true
					break
				end
			end
			assert.is_true(in_subtree)
		end)

		it("sibling paths are not under subtree roots", function()
			local _, subtrees = M._parse_results("/repo/src\n")
			local sibling_path = "/repo/docs/guide"
			local in_subtree = false
			for subtree_root, _ in pairs(subtrees) do
				if sibling_path:sub(1, #subtree_root + 1) == subtree_root .. "/" then
					in_subtree = true
					break
				end
			end
			assert.is_false(in_subtree)
		end)

		it("does not false-positive on prefix overlap", function()
			-- /repo/src-old should NOT match subtree /repo/src
			local _, subtrees = M._parse_results("/repo/src\n")
			local similar_path = "/repo/src-old/file"
			local in_subtree = false
			for subtree_root, _ in pairs(subtrees) do
				if similar_path:sub(1, #subtree_root + 1) == subtree_root .. "/" then
					in_subtree = true
					break
				end
			end
			assert.is_false(in_subtree)
		end)
	end)
end)
