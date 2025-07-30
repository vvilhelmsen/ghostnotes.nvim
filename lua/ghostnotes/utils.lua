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

return M
