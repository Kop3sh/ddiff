local M = {}

---@class DdiffBufState
---@field hunks table
---@field expanded_hunks table<integer, boolean>|nil
---@field debounce_timer userdata?

local state = {} ---@type table<integer, DdiffBufState>

function M.get_state(bufnr)
  bufnr = bufnr or 0
  local s = state[bufnr]
  if not s then
    return nil
  end
  return { hunks = s.hunks }
end

local function buf_should_track(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= ""
end

local function merge_delete_virt_lines(hunks)
  local by_line = {} ---@type table<integer, string[]>
  for _, h in ipairs(hunks) do
    if h.type == "delete" then
      local ln = h.line
      if not by_line[ln] then
        by_line[ln] = {}
      end
      vim.list_extend(by_line[ln], h.content)
    end
  end
  return by_line
end

---@param hunks table
---@param lnum integer
---@return integer|nil
local function hunk_id_at_line(hunks, lnum)
  for _, h in ipairs(hunks) do
    if h.line == lnum and h.hunk_id ~= nil then
      return h.hunk_id
    end
  end
  return nil
end

---@param expanded table<integer, boolean>|nil
---@param hunks table
local function prune_expanded(expanded, hunks)
  if not expanded then
    return {}
  end
  local valid = {}
  for _, h in ipairs(hunks) do
    if h.hunk_id then
      valid[h.hunk_id] = true
    end
  end
  local out = {}
  for hid, on in pairs(expanded) do
    if on and valid[hid] then
      out[hid] = true
    end
  end
  return out
end

--- Lines that belong to an expanded hunk (any row with that hunk_id).
---@param hunks table
---@param expanded table<integer, boolean>
---@return table<integer, true>
local function expanded_line_set(hunks, expanded)
  local lines = {}
  for _, h in ipairs(hunks) do
    if h.hunk_id and expanded[h.hunk_id] then
      lines[h.line] = true
    end
  end
  return lines
end

---@param hunks table
---@param skip_lines table<integer, true> lines that use block UI instead
---@return table<integer, "add"|"delete"|"change"|nil>
local function gutter_kind_per_line(hunks, skip_lines)
  local touched = {} ---@type table<integer, true>
  for _, h in ipairs(hunks) do
    if (h.type == "add" or h.type == "delete") and not skip_lines[h.line] then
      touched[h.line] = true
    end
  end
  local kind = {} ---@type table<integer, string>
  for L in pairs(touched) do
    local has_del, has_add = false, false
    for _, h in ipairs(hunks) do
      if h.line == L then
        if h.type == "delete" then
          has_del = true
        elseif h.type == "add" then
          has_add = true
        end
      end
    end
    if has_del and has_add then
      kind[L] = "change"
    elseif has_del then
      kind[L] = "delete"
    elseif has_add then
      kind[L] = "add"
    end
  end
  return kind
end

function M.clear(bufnr, opts)
  local ns = vim.api.nvim_create_namespace(opts.namespace)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  pcall(vim.fn.sign_unplace, opts.sign_group, { buffer = bufnr })
end

---@param bufnr integer
---@param hunks table
---@param opts table
function M.render(bufnr, hunks, opts)
  local prev_exp = (state[bufnr] and state[bufnr].expanded_hunks) and vim.deepcopy(state[bufnr].expanded_hunks) or {}

  M.clear(bufnr, opts)
  local ns = vim.api.nvim_create_namespace(opts.namespace)
  local stored = vim.deepcopy(hunks)
  local expanded = prune_expanded(prev_exp, stored)
  local sign_id_base = bufnr * 65536

  if opts.display == "cursor" then
    local exp_lines = expanded_line_set(stored, expanded)
    local subset = {}
    for _, h in ipairs(stored) do
      if h.hunk_id and expanded[h.hunk_id] then
        subset[#subset + 1] = h
      end
    end

    if #subset > 0 then
      local deletes = merge_delete_virt_lines(subset)
      for line, lines in pairs(deletes) do
        local virt_rows = {}
        for _, text in ipairs(lines) do
          virt_rows[#virt_rows + 1] = {
            { "- " .. text, "CursorDiffDelete" },
          }
        end
        local ext_id = vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
          virt_lines = virt_rows,
          virt_lines_above = true,
          hl_mode = "combine",
        })
        for _, h in ipairs(stored) do
          if h.type == "delete" and h.line == line and h.hunk_id and expanded[h.hunk_id] then
            h.virt_line_id = ext_id
          end
        end
      end
      local sign_name_add = opts.sign_group .. "_add"
      for _, h in ipairs(subset) do
        if h.type == "add" then
          vim.fn.sign_place(
            sign_id_base + 65536 + h.id,
            opts.sign_group,
            sign_name_add,
            bufnr,
            { lnum = h.line, priority = 10 }
          )
        end
      end
    end

    local kinds = gutter_kind_per_line(stored, exp_lines)
    local sg = opts.sign_group
    for line, k in pairs(kinds) do
      if k == "add" then
        vim.fn.sign_place(sign_id_base + line, opts.sign_group, sg .. "_gutter_add", bufnr, { lnum = line, priority = 5 })
      elseif k == "delete" then
        vim.fn.sign_place(sign_id_base + line, opts.sign_group, sg .. "_gutter_delete", bufnr, { lnum = line, priority = 5 })
      elseif k == "change" then
        vim.fn.sign_place(sign_id_base + line, opts.sign_group, sg .. "_gutter_change", bufnr, { lnum = line, priority = 5 })
      end
    end
  else
    local deletes = merge_delete_virt_lines(stored)
    for line, lines in pairs(deletes) do
      local virt_rows = {}
      for _, text in ipairs(lines) do
        virt_rows[#virt_rows + 1] = {
          { "- " .. text, "CursorDiffDelete" },
        }
      end
      local ext_id = vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
        virt_lines = virt_rows,
        virt_lines_above = true,
        hl_mode = "combine",
      })
      for _, h in ipairs(stored) do
        if h.type == "delete" and h.line == line then
          h.virt_line_id = ext_id
        end
      end
    end

    local sign_name = opts.sign_group .. "_add"
    for _, h in ipairs(stored) do
      if h.type == "add" then
        vim.fn.sign_place(
          sign_id_base + h.id,
          opts.sign_group,
          sign_name,
          bufnr,
          { lnum = h.line, priority = 10 }
        )
      end
    end
  end

  local st = state[bufnr] or {}
  st.hunks = stored
  st.expanded_hunks = expanded
  state[bufnr] = st
end

--- Toggle block-style UI for the hunk at `lnum` (cursor display only).
---@param bufnr integer
---@param lnum integer
---@param opts table
function M.expand_hunk_at_line(bufnr, lnum, opts)
  if opts.display ~= "cursor" then
    return
  end
  local st = state[bufnr]
  if not st or not st.hunks then
    return
  end
  local hid = hunk_id_at_line(st.hunks, lnum)
  if not hid then
    return
  end
  st.expanded_hunks = st.expanded_hunks or {}
  st.expanded_hunks[hid] = not st.expanded_hunks[hid]
  M.render(bufnr, st.hunks, opts)
end

---@param bufnr integer
---@param provider table
---@param opts table
function M.refresh(bufnr, provider, opts)
  if not buf_should_track(bufnr) then
    return
  end
  provider:get_diff(bufnr, function(err, hunks)
    if err then
      return
    end
    if not hunks then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    M.render(bufnr, hunks, opts)
  end)
end

---@param bufnr integer
---@param provider table
---@param opts table
function M.schedule_refresh(bufnr, provider, opts)
  local st = state[bufnr]
  if not st then
    st = {}
    state[bufnr] = st
  end
  if st.debounce_timer then
    st.debounce_timer:stop()
    st.debounce_timer:close()
    st.debounce_timer = nil
  end
  local timer = vim.loop.new_timer()
  st.debounce_timer = timer
  timer:start(opts.debounce_ms, 0, function()
    if st.debounce_timer ~= timer then
      return
    end
    st.debounce_timer = nil
    timer:stop()
    timer:close()
    vim.schedule(function()
      M.refresh(bufnr, provider, opts)
    end)
  end)
end

function M.detach(bufnr)
  local st = state[bufnr]
  if st and st.debounce_timer then
    st.debounce_timer:stop()
    st.debounce_timer:close()
    st.debounce_timer = nil
  end
  state[bufnr] = nil
end

function M.clear_all_expanded()
  for _, st in pairs(state) do
    if st then
      st.expanded_hunks = {}
    end
  end
end

--- Re-run `render` for every buffer that already has cached hunks (after global display change).
---@param opts table
function M.rerender_all_cached(opts)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local st = state[bufnr]
      if st and st.hunks then
        M.render(bufnr, st.hunks, opts)
      end
    end
  end
end

return M
