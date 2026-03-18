# neotree-whitelist.nvim

A Neovim plugin that filters [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) to show only directories found under a given directory name (pattern).

Useful for large monorepos where you want to focus the file tree on a specific subdirectory without changing your working directory.

## How it works

When activated, the plugin uses `fd` to enumerate all subdirectories under the given path and patches neo-tree's item creation to hide any directory not in that set. Parent directories are automatically included so the tree remains navigable, and matched directories show their full subtree.

## Requirements

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [`fd`](https://github.com/sharkdp/fd) (recommended, falls back to `find` if not available)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- neotree
{
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-tree/nvim-web-devicons', -- optional, but recommended
  },
  lazy = false, -- neo-tree will lazily load itself
},
-- THIS PLUGIN
{
  'rogovski/neotree-whitelist.nvim',
  lazy = false,
  dependencies = { 'nvim-neo-tree/neo-tree.nvim' },
  config = function()
    require('neotree-whitelist').setup()
  end,
}
```

## Usage

```
:NeotreeWhitelist [dir_pattern]
```

- **`dir_pattern`** — pattern of the directory name to filter by.

All directories outside the subtree rooted at `dir_pattern` will be hidden in the neo-tree filesystem panel. Run the command with `.` to clear the whitelist

## Notes

this is still rough around the edges and will throw errors lol for certain patterns passed as input (`:NeotreeWhitelist *`). these things should work though:

- `:NeotreeWhitelist ^foo`: dirs that start with 'foo'
- `:NeotreeWhitelist something`: dirs that contain 'something'
