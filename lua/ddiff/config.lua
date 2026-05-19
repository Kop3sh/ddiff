local M = {}

--- Highlights for `display = "cursor"` (merged before user overrides).
M.cursor_theme = {
  highlights = {
    CursorDiffAdd = { fg = "#28a745", bg = "NONE", bold = true },
    CursorDiffAddSign = { fg = "#28a745", bg = "NONE", bold = true },
    CursorDiffDelete = { fg = "#d73a49", bg = "#3a1d1d" },
    --- Gutter bars (no virtual text in cursor mode).
    DdiffGutterAdd = { fg = "#28a745", bg = "NONE", bold = true },
    DdiffGutterDelete = { fg = "#e5534b", bg = "NONE", bold = true },
    DdiffGutterChange = { fg = "#368cf9", bg = "NONE", bold = true },
  },
  --- Same glyph, different highlight groups.
  gutter_bar = {
    text = "▎",
    add = { hl_group = "DdiffGutterAdd" },
    delete = { hl_group = "DdiffGutterDelete" },
    change = { hl_group = "DdiffGutterChange" },
  },
}

M.defaults = {
  debounce_ms = 75,
  --- `"blocks"` — green `┃` + virtual deleted lines everywhere.
  --- `"cursor"` — green / red / blue gutter bars; click gutter to toggle block view for that hunk only.
  display = "cursor",
  signs = {
    add = { text = "┃", hl_group = "CursorDiffAddSign" },
  },
  highlights = {
    CursorDiffAdd = { fg = "#28a745", bg = "NONE", bold = true },
    CursorDiffAddSign = { fg = "#28a745", bg = "NONE", bold = true },
    CursorDiffDelete = { fg = "#d73a49", bg = "#3a1d1d" },
  },
  namespace = "ddiff",
  sign_group = "ddiff",
  --- Gutter click: only used when `display == "cursor"` (expand hunk to block UI).
  gutter_mouse = {
    enabled = true,
  },
  --- Hunk navigation (`]c` / `[c`); `wrap` jumps first↔last at buffer ends.
  nav = {
    wrap = false,
  },
  --- After `:DdiffQfHunks` / `:DdiffQfFiles` / `:DdiffQfHunksRepo`, open quickfix automatically.
  qf_open = true,
  --- Set `keymaps = false` to skip all; set individual values to `false` to unbind.
  keymaps = {
    toggle_display = "<leader>gd",
    toggle_hunk_expand = "<leader>gh",
    nav_next_hunk = "]c",
    nav_prev_hunk = "[c",
    qf_hunks = "<leader>hq",
    qf_hunks_repo = "<leader>hQ",
    qf_files = "<leader>hF",
  },
}

function M.resolve(user)
  user = user or {}
  local o = vim.deepcopy(M.defaults)
  if user.debounce_ms ~= nil then
    o.debounce_ms = user.debounce_ms
  end
  if user.display ~= nil then
    o.display = user.display
  end

  if o.display == "cursor" then
    for k, v in pairs(M.cursor_theme.highlights) do
      o.highlights[k] = vim.deepcopy(v)
    end
    o.gutter_bar = vim.deepcopy(M.cursor_theme.gutter_bar)
  end

  if user.signs and user.signs.add then
    if user.signs.add.text ~= nil then
      o.signs.add.text = user.signs.add.text
    end
    if user.signs.add.hl_group ~= nil then
      o.signs.add.hl_group = user.signs.add.hl_group
    end
  end
  if o.display == "cursor" and user.gutter_bar then
    o.gutter_bar = o.gutter_bar or {}
    if user.gutter_bar.text ~= nil then
      o.gutter_bar.text = user.gutter_bar.text
    end
    for _, k in ipairs({ "add", "delete", "change" }) do
      if user.gutter_bar[k] then
        o.gutter_bar[k] = o.gutter_bar[k] or {}
        if user.gutter_bar[k].hl_group ~= nil then
          o.gutter_bar[k].hl_group = user.gutter_bar[k].hl_group
        end
      end
    end
  end
  if user.highlights then
    for k, v in pairs(user.highlights) do
      o.highlights[k] = v
    end
  end
  if user.namespace ~= nil then
    o.namespace = user.namespace
  end
  if user.sign_group ~= nil then
    o.sign_group = user.sign_group
  end
  if user.gutter_mouse and user.gutter_mouse.enabled ~= nil then
    o.gutter_mouse.enabled = user.gutter_mouse.enabled
  end
  if user.nav then
    if user.nav.wrap ~= nil then
      o.nav.wrap = user.nav.wrap
    end
  end
  if user.qf_open ~= nil then
    o.qf_open = user.qf_open
  end
  if user.keymaps == false then
    o.keymaps = false
  elseif type(user.keymaps) == "table" then
    for k, v in pairs(user.keymaps) do
      o.keymaps[k] = v
    end
  end
  return o
end

return M
