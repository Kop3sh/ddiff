--- Hunk navigation (]c / [c style) using cached renderer hunks.
local renderer = require("ddiff.renderer")

local M = {}

---@param hunks table
---@return { line: integer, hunk_id: integer|string }[]
function M.hunk_starts(hunks)
  local minline = {} ---@type table<any, integer>
  for _, h in ipairs(hunks or {}) do
    if h.type == "add" or h.type == "delete" then
      local hid = h.hunk_id ~= nil and h.hunk_id or ("_line_" .. tostring(h.line))
      local L = h.line
      if not minline[hid] or L < minline[hid] then
        minline[hid] = L
      end
    end
  end
  local rows = {}
  for hid, L in pairs(minline) do
    rows[#rows + 1] = { line = L, hunk_id = hid }
  end
  table.sort(rows, function(a, b)
    return a.line < b.line
  end)
  return rows
end

---@param bufnr integer
---@param count integer
---@param opts table setup opts (`nav.wrap`)
function M.next_hunk(bufnr, count, opts)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local st = renderer.get_state(bufnr)
  if not st or not st.hunks then
    return
  end
  local rows = M.hunk_starts(st.hunks)
  if #rows == 0 then
    return
  end
  local wrap = opts and opts.nav and opts.nav.wrap
  if wrap == nil then
    wrap = true
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local n = math.max(1, count or 1)
  local target ---@type integer?
  for _ = 1, n do
    target = nil
    for _, r in ipairs(rows) do
      if r.line > cur then
        target = r.line
        break
      end
    end
    if target == nil then
      if wrap then
        target = rows[1].line
      else
        return
      end
    end
    cur = target
  end
  if target then
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

---@param bufnr integer
---@param count integer
---@param opts table
function M.prev_hunk(bufnr, count, opts)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local st = renderer.get_state(bufnr)
  if not st or not st.hunks then
    return
  end
  local rows = M.hunk_starts(st.hunks)
  if #rows == 0 then
    return
  end
  local wrap = opts and opts.nav and opts.nav.wrap
  if wrap == nil then
    wrap = true
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local n = math.max(1, count or 1)
  local target ---@type integer?
  for _ = 1, n do
    target = nil
    for i = #rows, 1, -1 do
      local r = rows[i]
      if r.line < cur then
        target = r.line
        break
      end
    end
    if target == nil then
      if wrap then
        target = rows[#rows].line
      else
        return
      end
    end
    cur = target
  end
  if target then
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

return M
