# neotree-whitelist.nvim

A Neovim plugin that filters [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) to show only directories found under a given directory name (pattern).

Useful for large monorepos where you want to focus the file tree on a specific subdirectory without changing your working directory.

## How it works

When activated, the plugin uses `fd` to enumerate all subdirectories under the given path and patches neo-tree's item creation to hide any directory not in that set. Parent directories are automatically included so the tree remains navigable, and matched directories show their full subtree.

## Requirements

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [`fd`](https://github.com/sharkdp/fd) (recommended, falls back to `find` if not available)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) (optional, required for the popup UI)

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

### Commands

| Command | Description |
|---|---|
| `:NeotreeWhitelist <pattern>` | Set a single whitelist pattern (clears any existing patterns) |
| `:NeotreeWhitelistAdd <pattern>` | Add a pattern to the whitelist |
| `:NeotreeWhitelistRemove <pattern>` | Remove a pattern from the whitelist |
| `:NeotreeWhitelistClear` | Clear all patterns and restore the full tree |
| `:NeotreeWhitelistList` | Print all active patterns |
| `:NeotreeWhitelistShow` | Open a popup to manage patterns (requires nui.nvim) |

### Multi-pattern support

You can maintain multiple whitelist patterns at once. Each pattern is matched independently and results are merged, so directories matching any pattern will be visible.

```
:NeotreeWhitelistAdd borders
:NeotreeWhitelistAdd ^config
```

### Visual indicator

When filtering is active, a `[Whitelist: <pattern>]` or `[Whitelist: N patterns]` label appears on the root node of the neo-tree filesystem panel.

### Popup UI

`:NeotreeWhitelistShow` opens an editable floating popup listing one pattern per line. Edit the buffer like normal text — add, remove, or reorder lines — then press `q`, `<Esc>`, or `<CR>` to save and close. Empty lines are ignored.

### Pattern examples

- `:NeotreeWhitelist ^foo` — dirs that start with "foo"
- `:NeotreeWhitelist something` — dirs that contain "something"
