# neotree-whitelist.nvim

A Neovim plugin that filters [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) to show only directories found under a given path.

Useful for large monorepos where you want to focus the file tree on a specific subdirectory without changing your working directory.

## How it works

When activated, the plugin uses `fd` to enumerate all subdirectories under the given path and patches neo-tree's item creation to hide any directory not in that set. Parent directories are automatically included so the tree remains navigable, and matched directories show their full subtree.

## Requirements

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [`fd`](https://github.com/sharkdp/fd) (must be in `$PATH`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'rogovski/neotree-whitelist.nvim',
  dev = true,
  lazy = false,
  dependencies = { 'nvim-neo-tree/neo-tree.nvim' },
  config = function()
    require('neotree-whitelist').setup()
  end,
}
```

## Usage

```
:NeotreeWhitelist [dir]
```

- **`dir`** — absolute or relative path to filter by. Defaults to the current working directory if omitted.

All directories outside the subtree rooted at `dir` will be hidden in the neo-tree filesystem panel. Run the command again with a different path to switch focus.
