local M = require("neotree-whitelist")

describe("_parse_results", function()
	it("returns empty tables for empty input", function()
		local paths, subtrees = M._parse_results("")
		assert.same({}, paths)
		assert.same({}, subtrees)
	end)

	it("parses a single absolute path", function()
		local paths, subtrees = M._parse_results("/home/user/repo/src\n")
		assert.is_true(subtrees["/home/user/repo/src"])
		-- The path and all parents should be in paths
		assert.is_true(paths["/home/user/repo/src"])
		assert.is_true(paths["/home/user/repo"])
		assert.is_true(paths["/home/user"])
		assert.is_true(paths["/home"])
	end)

	it("parses multiple paths", function()
		local input = "/a/b/foo\n/a/c/foo\n"
		local paths, subtrees = M._parse_results(input)

		assert.is_true(subtrees["/a/b/foo"])
		assert.is_true(subtrees["/a/c/foo"])

		-- Shared parent /a should be included
		assert.is_true(paths["/a"])
		-- Distinct parents
		assert.is_true(paths["/a/b"])
		assert.is_true(paths["/a/c"])
	end)

	it("strips trailing slashes from paths", function()
		local paths, subtrees = M._parse_results("/a/b/foo/\n")
		assert.is_true(subtrees["/a/b/foo"])
		assert.is_nil(subtrees["/a/b/foo/"])
	end)

	it("ignores blank lines", function()
		local paths, subtrees = M._parse_results("\n\n/a/b\n\n")
		assert.is_true(paths["/a/b"])
		assert.is_true(paths["/a"])
		-- Only one subtree entry
		local count = 0
		for _ in pairs(subtrees) do
			count = count + 1
		end
		assert.equals(1, count)
	end)
end)
