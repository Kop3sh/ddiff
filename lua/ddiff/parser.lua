--- Parse `git diff --unified=0 --no-color -- <path>` (single-file diff).
--- @param diff_text string
--- @return { type: string, line: integer, content: string[], id: integer, hunk_id: integer }[]
local M = {}

local function parse_hunk_header(line)
  local old_s, old_c, new_s, new_c =
    line:match("^@@ %-(%d+),(%d+)%s*%+(%d+),(%d+)%s*@@")
  if old_s then
    return tonumber(old_s), tonumber(old_c), tonumber(new_s), tonumber(new_c)
  end

  old_s, old_c, new_s = line:match("^@@ %-(%d+),(%d+)%s*%+(%d+)%s*@@")
  if old_s then
    return tonumber(old_s), tonumber(old_c), tonumber(new_s), 1
  end

  old_s, new_s, new_c = line:match("^@@ %-(%d+)%s*%+(%d+),(%d+)%s*@@")
  if old_s then
    return tonumber(old_s), 1, tonumber(new_s), tonumber(new_c)
  end

  old_s, new_s = line:match("^@@ %-(%d+)%s*%+(%d+)%s*@@")
  if old_s then
    return tonumber(old_s), 1, tonumber(new_s), 1
  end

  return nil
end

function M.parse_git_diff(diff_text)
  local out = {}
  local id = 0
  local hunk_seq = 0
  local lines = vim.split(diff_text, "\n", { plain = true })
  local i = 1

  while i <= #lines do
    local line = lines[i]
    if vim.startswith(line, "@@ ") then
      local old_start, _, new_start = parse_hunk_header(line)
      if old_start and new_start then
        hunk_seq = hunk_seq + 1
        local hunk_id = hunk_seq
        local pos_old = old_start
        local pos_new = new_start
        i = i + 1
        while i <= #lines do
          local l = lines[i]
          if vim.startswith(l, "@@ ") or vim.startswith(l, "diff ") then
            break
          end
          if vim.startswith(l, "\\") then
            i = i + 1
            break
          end
          local prefix = l:sub(1, 1)
          local body = l:sub(2)

          if prefix == " " then
            pos_old = pos_old + 1
            pos_new = pos_new + 1
          elseif prefix == "-" then
            id = id + 1
            out[#out + 1] = {
              type = "delete",
              line = pos_new,
              content = { body },
              virt_line_id = nil,
              id = id,
              hunk_id = hunk_id,
            }
            pos_old = pos_old + 1
          elseif prefix == "+" then
            id = id + 1
            out[#out + 1] = {
              type = "add",
              line = pos_new,
              content = { body },
              virt_line_id = nil,
              id = id,
              hunk_id = hunk_id,
            }
            pos_new = pos_new + 1
          end
          i = i + 1
        end
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return out
end

return M
