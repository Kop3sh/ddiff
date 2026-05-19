local config = require("ddiff.config")
local nav = require("ddiff.nav")
local provider_mod = require("ddiff.provider")
local quickfix = require("ddiff.quickfix")
local renderer = require("ddiff.renderer")

local M = {}

--- shallow copy of last `setup()` argument for `config.resolve()` on toggles
local user_config = {}
local setup_opts ---@type table
local active_provider ---@type table

local function apply_highlights(highlights)
  for name, def in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, def)
  end
end

local function define_signs(opts)
  vim.fn.sign_define(opts.sign_group .. "_add", {
    text = opts.signs.add.text,
    texthl = opts.signs.add.hl_group,
  })
  if opts.display == "cursor" then
    local bar = opts.gutter_bar or {}
    local t = bar.text or "▎"
    vim.fn.sign_define(opts.sign_group .. "_gutter_add", {
      text = t,
      texthl = (bar.add or {}).hl_group or "DdiffGutterAdd",
    })
    vim.fn.sign_define(opts.sign_group .. "_gutter_delete", {
      text = t,
      texthl = (bar.delete or {}).hl_group or "DdiffGutterDelete",
    })
    vim.fn.sign_define(opts.sign_group .. "_gutter_change", {
      text = t,
      texthl = (bar.change or {}).hl_group or "DdiffGutterChange",
    })
  end
end

local function opts_getter()
  return setup_opts
end

--- Flip `blocks` ↔ `cursor` for the whole editor, re-apply highlights/signs, clear expanded hunks, redraw cached buffers.
function M.toggle_display()
  if not setup_opts then
    return
  end
  user_config.display = (setup_opts.display == "cursor") and "blocks" or "cursor"
  setup_opts = config.resolve(user_config)
  apply_highlights(setup_opts.highlights)
  define_signs(setup_opts)
  renderer.clear_all_expanded()
  renderer.rerender_all_cached(setup_opts)
end

--- Toggle block-style UI for the hunk at the cursor line (`display == "cursor"` only).
function M.toggle_hunk_expand()
  if not setup_opts or setup_opts.display ~= "cursor" then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  renderer.expand_hunk_at_line(bufnr, lnum, setup_opts)
end

---@param bufnr integer|nil 0 or nil = current buffer
function M.next_hunk(bufnr)
  if not setup_opts then
    return
  end
  local c = math.max(vim.v.count, 1)
  nav.next_hunk(bufnr or 0, c, setup_opts)
end

---@param bufnr integer|nil 0 or nil = current buffer
function M.prev_hunk(bufnr)
  if not setup_opts then
    return
  end
  local c = math.max(vim.v.count, 1)
  nav.prev_hunk(bufnr or 0, c, setup_opts)
end

--- Fill quickfix with one entry per hunk in `bufnr` (cached diff).
---@param bufnr integer|nil
function M.set_qf_hunks(bufnr)
  if not setup_opts then
    return
  end
  quickfix.set_qf_hunks(bufnr or 0, setup_opts)
end

--- Fill quickfix with every unstaged file in the repo (`git diff --name-only`).
---@param bufnr integer|nil used to find git root
function M.set_qf_files(bufnr)
  if not setup_opts then
    return
  end
  quickfix.set_qf_files(bufnr or 0, setup_opts)
end

--- All unstaged hunks in the repo → quickfix (one row per hunk, any file).
---@param bufnr integer|nil used to find git root
function M.set_qf_hunks_repo(bufnr)
  if not setup_opts then
    return
  end
  quickfix.set_qf_hunks_repo(bufnr or 0, setup_opts)
end

function M.setup(user)
  user_config = vim.tbl_deep_extend("force", {}, user or {})
  setup_opts = config.resolve(user_config)
  apply_highlights(setup_opts.highlights)
  define_signs(setup_opts)

  active_provider = user and user.provider or provider_mod.git()

  if setup_opts.gutter_mouse.enabled then
    require("ddiff.gutter_mouse").install(opts_getter)
  end

  local group = vim.api.nvim_create_augroup("ddiff", { clear = true })

  local function on_buf(ev)
    local bufnr = ev.buf
    if vim.bo[bufnr].buftype ~= "" then
      return
    end
    if vim.api.nvim_buf_get_name(bufnr) == "" then
      return
    end
    renderer.schedule_refresh(bufnr, active_provider, setup_opts)
  end

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = on_buf,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group,
    callback = on_buf,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      renderer.clear(ev.buf, setup_opts)
      renderer.detach(ev.buf)
    end,
  })

  vim.api.nvim_create_user_command("DdiffRefresh", function()
    local bufnr = vim.api.nvim_get_current_buf()
    renderer.refresh(bufnr, active_provider, setup_opts)
  end, { desc = "Refresh ddiff overlays for current buffer" })

  vim.api.nvim_create_user_command("DdiffToggleDisplay", function()
    M.toggle_display()
  end, { desc = "Toggle ddiff display: blocks ↔ cursor (global)" })

  vim.api.nvim_create_user_command("DdiffToggleHunk", function()
    M.toggle_hunk_expand()
  end, { desc = "Toggle block UI for hunk at cursor (cursor display only)" })

  vim.api.nvim_create_user_command("DdiffQfHunks", function()
    M.set_qf_hunks(0)
  end, { desc = "Quickfix: one entry per hunk (current buffer)" })

  vim.api.nvim_create_user_command("DdiffQfFiles", function()
    M.set_qf_files(0)
  end, { desc = "Quickfix: unstaged changed files in repo" })

  vim.api.nvim_create_user_command("DdiffQfHunksRepo", function()
    M.set_qf_hunks_repo(0)
  end, { desc = "Quickfix: every unstaged hunk in the repo" })

  if setup_opts.keymaps ~= false then
    local km = setup_opts.keymaps
    if km.toggle_display then
      vim.keymap.set("n", km.toggle_display, M.toggle_display, { desc = "ddiff: toggle blocks/cursor display" })
    end
    if km.toggle_hunk_expand then
      vim.keymap.set("n", km.toggle_hunk_expand, M.toggle_hunk_expand, { desc = "ddiff: toggle hunk block UI" })
    end
    if km.nav_next_hunk then
      vim.keymap.set({ "n", "x" }, km.nav_next_hunk, function()
        M.next_hunk(0)
      end, { desc = "ddiff: next hunk" })
    end
    if km.nav_prev_hunk then
      vim.keymap.set({ "n", "x" }, km.nav_prev_hunk, function()
        M.prev_hunk(0)
      end, { desc = "ddiff: previous hunk" })
    end
    if km.qf_hunks then
      vim.keymap.set("n", km.qf_hunks, function()
        M.set_qf_hunks(0)
      end, { desc = "ddiff: hunks → quickfix" })
    end
    if km.qf_files then
      vim.keymap.set("n", km.qf_files, function()
        M.set_qf_files(0)
      end, { desc = "ddiff: changed files → quickfix" })
    end
    if km.qf_hunks_repo then
      vim.keymap.set("n", km.qf_hunks_repo, function()
        M.set_qf_hunks_repo(0)
      end, { desc = "ddiff: all repo hunks → quickfix" })
    end
  end
end


return M
