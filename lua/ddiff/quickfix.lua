--- Quickfix from git: current-buffer hunks or repo-wide changed files.
local nav = require("ddiff.nav")
local parser = require("ddiff.parser")
local provider = require("ddiff.provider")
local renderer = require("ddiff.renderer")

local M = {}

---@param opts table|nil
local function maybe_open_qf(opts)
  if opts and opts.qf_open then
    vim.cmd.copen()
  end
end

--- Current buffer: one qf entry per hunk (jump to first line of each hunk).
---@param bufnr integer
---@param opts table|nil
function M.set_qf_hunks(bufnr, opts)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local st = renderer.get_state(bufnr)
  if not st or not st.hunks then
    vim.fn.setqflist({}, "r", { title = "ddiff: hunks", items = {} })
    maybe_open_qf(opts)
    return
  end
  local rows = nav.hunk_starts(st.hunks)
  local items = {}
  for _, r in ipairs(rows) do
    items[#items + 1] = {
      bufnr = bufnr,
      lnum = r.line,
      col = 0,
      text = "hunk " .. tostring(r.hunk_id),
    }
  end
  vim.fn.setqflist({}, "r", { title = "ddiff: hunks", items = items })
  maybe_open_qf(opts)
end

--- Repo working tree: one qf entry per file with unstaged changes (`git diff --name-only`).
---@param bufnr integer used only to locate git root (0 = current buffer)
---@param opts table|nil
function M.set_qf_files(bufnr, opts)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    vim.fn.setqflist({}, "r", { title = "ddiff: files", items = {} })
    maybe_open_qf(opts)
    return
  end
  path = vim.fs.normalize(path)
  local root = provider.git_root(path)
  if not root then
    vim.fn.setqflist({}, "r", { title = "ddiff: files", items = {} })
    maybe_open_qf(opts)
    return
  end
  local obj = vim.system({ "git", "diff", "--name-only" }, { cwd = root, text = true }):wait()
  if obj.code ~= 0 then
    vim.fn.setqflist({}, "r", { title = "ddiff: files", items = {} })
    maybe_open_qf(opts)
    return
  end
  local items = {}
  for _, rel in ipairs(vim.split(vim.trim(obj.stdout or ""), "\n", { plain = true })) do
    if rel ~= "" then
      local abs = vim.fs.normalize(vim.fs.joinpath(root, rel))
      items[#items + 1] = {
        filename = abs,
        lnum = 1,
        col = 0,
        text = rel,
      }
    end
  end
  vim.fn.setqflist({}, "r", { title = "ddiff: changed files", items = items })
  maybe_open_qf(opts)
end

--- Every unstaged file in the repo: one quickfix entry per hunk (`git diff -U0` per file).
---@param bufnr integer used only to locate git root (0 = current buffer)
---@param opts table|nil
function M.set_qf_hunks_repo(bufnr, opts)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    vim.fn.setqflist({}, "r", { title = "ddiff: repo hunks", items = {} })
    maybe_open_qf(opts)
    return
  end
  path = vim.fs.normalize(path)
  local root = provider.git_root(path)
  if not root then
    vim.fn.setqflist({}, "r", { title = "ddiff: repo hunks", items = {} })
    maybe_open_qf(opts)
    return
  end
  local list_obj = vim.system({ "git", "diff", "--name-only" }, { cwd = root, text = true }):wait()
  if list_obj.code ~= 0 then
    vim.fn.setqflist({}, "r", { title = "ddiff: repo hunks", items = {} })
    maybe_open_qf(opts)
    return
  end
  local items = {}
  for _, rel in ipairs(vim.split(vim.trim(list_obj.stdout or ""), "\n", { plain = true })) do
    if rel ~= "" then
      local diff_obj = vim.system({
        "git",
        "diff",
        "--unified=0",
        "--no-color",
        "--",
        rel,
      }, { cwd = root, text = true }):wait()
      local hunks = parser.parse_git_diff(diff_obj.stdout or "")
      local abs = vim.fs.normalize(vim.fs.joinpath(root, rel))
      for _, row in ipairs(nav.hunk_starts(hunks)) do
        items[#items + 1] = {
          filename = abs,
          lnum = row.line,
          col = 0,
          text = rel .. " — hunk " .. tostring(row.hunk_id),
        }
      end
    end
  end
  table.sort(items, function(a, b)
    if a.filename ~= b.filename then
      return a.filename < b.filename
    end
    return a.lnum < b.lnum
  end)
  vim.fn.setqflist({}, "r", { title = "ddiff: repo hunks", items = items })
  maybe_open_qf(opts)
end

return M
