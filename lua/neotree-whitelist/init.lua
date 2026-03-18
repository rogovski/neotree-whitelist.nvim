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
  local file_items = require 'neo-tree.sources.common.file-items'
  local original_create_item = file_items.create_item

  file_items.create_item = function(context, path, _type)
    local item = original_create_item(context, path, _type)

    if M._state.active and item then
      -- If it's a directory and not in the whitelist, hide it
      if item.type == 'directory' and not M._state.paths[item.path] then
        -- Also allow the item if it lives inside a matched subtree
        local in_subtree = false
        for subtree_root, _ in pairs(M._state.subtrees) do
          if item.path:sub(1, #subtree_root + 1) == subtree_root .. '/' then
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

  vim.api.nvim_create_user_command('UpdateNeotreeWhitelist', function(cmd_opts)
    M.update(cmd_opts.args ~= '' and cmd_opts.args or nil)
  end, { nargs = '?' })
end

function M.update(dir)
  dir = dir or vim.fn.getcwd()
  -- Strip trailing slash from dir if present for consistency
  dir = dir:gsub('/$', '')

  print 'Wait!'
  local cmd = string.format('fd --type d --absolute-path %s', vim.fn.shellescape(dir))
  local handle = io.popen(cmd)
  local result = handle:read '*a'
  handle:close()

  local new_paths = {}
  local new_subtrees = {}
  -- Always include the root directory itself
  new_paths[dir] = true

  for line in result:gmatch '[^\r\n]+' do
    local path = line:gsub('/$', '') -- Strip trailing slash from fd output

    -- Mark this matched directory as a subtree root (all children are visible)
    new_subtrees[path] = true

    -- Add the path and all its parents up to the dir
    local current = path
    while current and #current >= #dir do
      new_paths[current] = true
      current = vim.fn.fnamemodify(current, ':h')
      if current == '/' or current == '.' then
        break
      end
    end
  end

  M._state.paths = new_paths
  M._state.subtrees = new_subtrees
  M._state.active = true
  require('neo-tree.sources.manager').refresh 'filesystem'
  print 'Neo-tree whitelist updated!'
end

return M
