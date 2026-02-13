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

function M.get_preview_dir()
  local dir = vim.fn.stdpath("data") .. "/ghostnotes/previews"
  vim.fn.mkdir(dir, "p")
  return dir
end

-- Generate unique file names
local function simple_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 2147483647
  end
  return string.format("%x", hash)
end

-- Creates or updates a preview markdown file for a note
function M.create_preview_file(note)
  local preview_dir = M.get_preview_dir()
  
  local unique_str = (note.bufname or "") .. ":" .. tostring(note.row or 0) .. ":" .. (note.timestamp or "")
  local hash = simple_hash(unique_str)
  local preview_path = preview_dir .. "/" .. hash .. ".md"
  
  -- Write note content to markdown file
  local content = note.text or ""
  local lines = vim.split(content, "\n", { plain = true })
  vim.fn.writefile(lines, preview_path)
  
  return preview_path
end

return M
