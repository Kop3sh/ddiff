--- Gutter click (cursor display): toggle block-style UI for the hunk at the clicked line.
--- `opts_getter` returns current resolved opts (so display mode can change without remapping).
local renderer = require("ddiff.renderer")

local M = {}

---@param pos table getmousepos() dict
---@return { winid: integer, bufnr: integer, lnum: integer }|nil
local function gutter_hit(pos)
  if pos.winid == 0 then
    return nil
  end
  local wi = vim.fn.getwininfo(pos.winid)[1]
  if type(wi) ~= "table" then
    return nil
  end
  if pos.wincol > (wi.textoff or 0) then
    return nil
  end
  local bufnr = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[bufnr].buftype ~= "" then
    return nil
  end
  local lnum = pos.line
  if lnum < 1 or lnum > vim.api.nvim_buf_line_count(bufnr) then
    return nil
  end
  return { winid = pos.winid, bufnr = bufnr, lnum = lnum }
end

---@param opts_getter fun(): table
function M.install(opts_getter)
  local function rhs()
    local opts = opts_getter()
    if not opts.gutter_mouse or not opts.gutter_mouse.enabled or opts.display ~= "cursor" then
      return "<LeftMouse>"
    end
    local pos = vim.fn.getmousepos()
    local g = gutter_hit(pos)
    if not g then
      return "<LeftMouse>"
    end

    local ctx = g
    vim.schedule(function()
      local o = opts_getter()
      if not vim.api.nvim_win_is_valid(ctx.winid) or not vim.api.nvim_buf_is_valid(ctx.bufnr) then
        return
      end
      if o.display ~= "cursor" or not o.gutter_mouse.enabled then
        return
      end
      vim.api.nvim_set_current_win(ctx.winid)
      vim.api.nvim_win_set_cursor(ctx.winid, { ctx.lnum, 0 })
      renderer.expand_hunk_at_line(ctx.bufnr, ctx.lnum, o)
    end)
    return "<Ignore>"
  end

  vim.keymap.set({ "n", "x" }, "<LeftMouse>", rhs, { expr = true, desc = "ddiff: gutter expand hunk" })
end

return M
