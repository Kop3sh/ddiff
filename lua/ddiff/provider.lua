local parser = require("ddiff.parser")

local M = {}

local GitProvider = {}
GitProvider.__index = GitProvider

function M.git(opts)
  opts = opts or {}
  return setmetatable({
    kind = "git",
    binary = opts.binary or "git",
  }, GitProvider)
end

---@param path string
---@return string?
function M.git_root(path)
  if not path or path == "" then
    return nil
  end
  local dir = vim.fs.dirname(path)
  local obj = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }):wait()
  if obj.code ~= 0 then
    return nil
  end
  return vim.trim(obj.stdout or "")
end

---@param self GitProvider
---@param bufnr integer
---@param cb fun(err: string?, hunks: table?)
function GitProvider:get_diff(bufnr, cb)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    vim.schedule(function()
      cb("buffer has no path", nil)
    end)
    return
  end
  path = vim.fs.normalize(path)
  local cwd = M.git_root(path)
  if not cwd then
    vim.schedule(function()
      cb("not inside a git repository", nil)
    end)
    return
  end

  vim.system({
    self.binary,
    "diff",
    "--unified=0",
    "--no-color",
    "--",
    path,
  }, { cwd = cwd, text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 and (obj.stdout or "") == "" then
        local err = obj.stderr
        if err == nil or err == "" then
          err = "git diff exited " .. tostring(obj.code)
        end
        cb(err, nil)
        return
      end
      local hunks = parser.parse_git_diff(obj.stdout or "")
      cb(nil, hunks)
    end)
  end)
end

local JjProvider = {}
JjProvider.__index = JjProvider

function M.jujutsu(_opts)
  return setmetatable({ kind = "jj" }, JjProvider)
end

function JjProvider:get_diff(_, cb)
  vim.schedule(function()
    cb("jujutsu provider not implemented", nil)
  end)
end

return M
