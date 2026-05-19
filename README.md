# ddiff

In-buffer **phantom diffs** for Neovim: show unstaged git changes as signs and virtual text on the file you are editing, without opening a split or `:diffthis`.

Requires Neovim 0.10+ and a git repository (working tree diff against the index).

## Install

Add the plugin to your path, then call `setup()` once (e.g. in your `init.lua` or lazy spec `config`).

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
  "your-user/ddiff",
  config = function()
    require("ddiff").setup()
  end,
}
```

## Quick start

```lua
require("ddiff").setup()
```

Open a file with unstaged edits inside a git repo. Overlays refresh on `BufEnter`, `TextChanged`, and `InsertLeave` (debounced).

## Display modes

| Mode | Behavior |
|------|----------|
| `"cursor"` (default) | Colored gutter bars (add / delete / change). Click the gutter or use `<leader>gh` to expand one hunk into full block UI (virtual deleted lines + add sign). |
| `"blocks"` | Full diff UI everywhere: green add sign and virtual deleted lines for every hunk. |

Toggle globally: `<leader>gd`, `:DdiffToggleDisplay`, or `require("ddiff").toggle_display()`.

## Configuration

All options are passed to `require("ddiff").setup({ ... })`.

| Option | Default | Description |
|--------|---------|-------------|
| `debounce_ms` | `75` | Delay before re-running `git diff` after edits. |
| `display` | `"cursor"` | `"cursor"` or `"blocks"`. |
| `signs.add` | `{ text = "┃", hl_group = "CursorDiffAddSign" }` | Sign for added lines (blocks mode and expanded hunks). |
| `gutter_bar` | see `config.lua` | Gutter glyph and highlight groups when `display == "cursor"`. |
| `highlights` | green add, red delete | Passed to `nvim_set_hl`. Cursor mode merges `DdiffGutter*` groups. |
| `namespace` | `"ddiff"` | Extmark namespace name. |
| `sign_group` | `"ddiff"` | Sign group prefix. |
| `gutter_mouse.enabled` | `true` | Click gutter to expand hunk (cursor mode only). |
| `nav.wrap` | `false` | Wrap `]c` / `[c` at buffer ends. |
| `qf_open` | `true` | Open quickfix after `:DdiffQf*` commands. |
| `keymaps` | see below | Set to `false` to disable all; set a key to `false` to unbind one. |
| `provider` | `require("ddiff.provider").git()` | Diff source (git implemented; jujutsu stub). |

Default keymaps (normal unless noted):

| Key | Action |
|-----|--------|
| `<leader>gd` | Toggle `cursor` ↔ `blocks` |
| `<leader>gh` | Toggle block UI for hunk at cursor |
| `]c` | Next hunk (also visual mode) |
| `[c` | Previous hunk |
| `<leader>hq` | Quickfix: hunks in current buffer |
| `<leader>hF` | Quickfix: changed files in repo |
| `<leader>hQ` | Quickfix: all unstaged hunks in repo |

## Config examples

### Defaults only

```lua
require("ddiff").setup()
```

### Classic full-buffer diff (blocks mode)

```lua
require("ddiff").setup({
  display = "blocks",
})
```

### Slower refresh (large files)

```lua
require("ddiff").setup({
  debounce_ms = 200,
})
```

### Custom colors

```lua
require("ddiff").setup({
  highlights = {
    CursorDiffAdd = { fg = "#7eca9c", bold = true },
    CursorDiffAddSign = { fg = "#7eca9c", bold = true },
    CursorDiffDelete = { fg = "#f7768e", bg = "#2d2028" },
    DdiffGutterAdd = { fg = "#7eca9c", bold = true },
    DdiffGutterDelete = { fg = "#f7768e", bold = true },
    DdiffGutterChange = { fg = "#7aa2f7", bold = true },
  },
})
```

### Custom gutter bar (cursor mode)

```lua
require("ddiff").setup({
  display = "cursor",
  gutter_bar = {
    text = "│",
    add = { hl_group = "DdiffGutterAdd" },
    delete = { hl_group = "DdiffGutterDelete" },
    change = { hl_group = "DdiffGutterChange" },
  },
})
```

### Custom add sign

```lua
require("ddiff").setup({
  signs = {
    add = { text = "+", hl_group = "CursorDiffAddSign" },
  },
})
```

### Your own keymaps (disable built-ins)

```lua
require("ddiff").setup({
  keymaps = false,
})

vim.keymap.set("n", "<leader>d", require("ddiff").toggle_display, { desc = "ddiff: display" })
vim.keymap.set("n", "]d", function()
  require("ddiff").next_hunk()
end, { desc = "ddiff: next hunk" })
vim.keymap.set("n", "[d", function()
  require("ddiff").prev_hunk()
end, { desc = "ddiff: prev hunk" })
```

### Partial keymap overrides

```lua
require("ddiff").setup({
  keymaps = {
    toggle_display = "<leader>D",
    nav_next_hunk = "]h",
    nav_prev_hunk = "[h",
    qf_hunks = false, -- unbind this one
  },
})
```

### Wrapping hunk navigation

```lua
require("ddiff").setup({
  nav = { wrap = true },
})
```

### No gutter click; keyboard expand only

```lua
require("ddiff").setup({
  gutter_mouse = { enabled = false },
})
```

### Quickfix without auto-open

```lua
require("ddiff").setup({
  qf_open = false,
})
```

### Non-default git binary

```lua
local provider = require("ddiff.provider")

require("ddiff").setup({
  provider = provider.git({ binary = "/opt/homebrew/bin/git" }),
})
```

### Full example (lazy.nvim)

```lua
{
  dir = vim.fn.stdpath("config") .. "/ddiff", -- or your fork URL
  config = function()
    require("ddiff").setup({
      display = "cursor",
      debounce_ms = 100,
      nav = { wrap = true },
      gutter_mouse = { enabled = true },
      highlights = {
        CursorDiffDelete = { fg = "#e06c75", bg = "#3d2a2a" },
      },
      keymaps = {
        toggle_display = "<leader>gd",
        toggle_hunk_expand = "<leader>gh",
        nav_next_hunk = "]c",
        nav_prev_hunk = "[c",
      },
    })
  end,
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:DdiffRefresh` | Re-fetch diff for current buffer |
| `:DdiffToggleDisplay` | Toggle `cursor` ↔ `blocks` globally |
| `:DdiffToggleHunk` | Toggle block UI for hunk at cursor |
| `:DdiffQfHunks` | Quickfix: one entry per hunk (current buffer) |
| `:DdiffQfFiles` | Quickfix: unstaged changed files |
| `:DdiffQfHunksRepo` | Quickfix: every unstaged hunk in the repo |

## API

```lua
local ddiff = require("ddiff")

ddiff.setup({ ... })
ddiff.toggle_display()
ddiff.toggle_hunk_expand()
ddiff.next_hunk(bufnr)  -- nil/0 = current buffer
ddiff.prev_hunk(bufnr)
ddiff.set_qf_hunks(bufnr)
ddiff.set_qf_files(bufnr)
ddiff.set_qf_hunks_repo(bufnr)

-- Cached hunks for a buffer (after refresh)
local state = require("ddiff.renderer").get_state(0)
if state then
  vim.print(state.hunks)
end
```

Hunk entries look like `{ type = "add"|"delete", line = number, content = string[], id = number, hunk_id = number }`.

## Providers

- **git** — `git diff --unified=0 --no-color -- <file>` against the index (default).
- **jujutsu** — stub only; `setup({ provider = require("ddiff.provider").jujutsu() })` will not produce overlays yet.

## Limitations

- Tracks normal file buffers with a path on disk; skips special buffers.
- Diff is unstaged working tree vs index (same as `git diff <file>`).
- Count on `]c` / `[c` repeats navigation (`3]c` = three hunks).

## Disclosure

- This plugin was moslty developed using LLMs, because other alternatives didn't seem to fit my needs (and/ or due to skill issues).
