local M = {}

function M.get_git_root()
  local output = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  return vim.v.shell_error == 0 and output or nil
end

function M.read_json(path)
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then return {} end
  local joined = table.concat(content, "\n")
  local ok, data = pcall(vim.fn.json_decode, joined)
  return ok and data or {}
end

function M.write_json(path, data)
  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then return end
  vim.fn.writefile(vim.split(json, "\n"), path)
end

-- Finds file containing all ghost notes
function M.get_global_path()
  local dir = vim.fn.stdpath("data") .. "/ghostnotes"
  vim.fn.mkdir(dir, "p")
  return dir .. "/ghostnotes.json"
end

-- Finds notes in git project
function M.find_notes_project()
  local git_root = M.get_git_root()
  if not git_root then
    vim.notify("Not inside a Git project", vim.log.levels.WARN)
    return
  end

  local path = git_root .. "/.ghostnotes.json"
  local project_notes = M.read_json(path)
  if vim.tbl_isempty(project_notes) then
    vim.notify("No project ghost notes", vim.log.levels.INFO)
    return
  end

  vim.ui.select(project_notes, {
    prompt = "Project Ghost Notes",
    format_item = function(item)
      local name = vim.fn.fnamemodify(item.bufname, ":t")
      return string.format("%s:%d → %s", name, item.row + 1, item.text)
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. vim.fn.fnameescape(choice.bufname))
      vim.api.nvim_win_set_cursor(0, { choice.row + 1, 0 })
    end
  end)
end

return M
