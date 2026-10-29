local M = {}
local uv = vim.uv or vim.loop

---Return the Git root for a file, or for the current directory when omitted.
---@param file? string
---@return string?
function M.get_git_root(file)
  if vim.fn.executable("git") == 0 then return nil end
  local dir = file and vim.fn.fnamemodify(file, ":p:h") or vim.fn.getcwd()
  local output = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  return vim.v.shell_error == 0 and output[1] or nil
end

---Read a note store. Missing files are empty; invalid files must not be overwritten.
---@param path string
---@return GhostnotesNote[]
function M.read_json(path)
  if not uv.fs_stat(path) then return {} end

  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then error("ghostnotes: cannot read " .. path .. ": " .. tostring(content)) end
  local decoded, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  local islist = vim.islist or vim.tbl_islist
  if not decoded or type(data) ~= "table" or not islist(data) then
    error("ghostnotes: invalid note store " .. path .. "; refusing to overwrite it")
  end
  for _, note in ipairs(data) do
    if type(note) ~= "table" or type(note.bufname) ~= "string" or type(note.text) ~= "string"
      or type(note.row) ~= "number" or note.row < 0 or note.row % 1 ~= 0 then
      error("ghostnotes: invalid note in " .. path .. "; refusing to overwrite it")
    end
  end
  return data
end

---Replace a note store using a temporary file in the same directory.
---@param path string
---@param data GhostnotesNote[]
function M.write_json(path, data)
  local json = vim.fn.json_encode(data)
  local fd, temp = uv.fs_mkstemp(path .. ".tmp.XXXXXX")
  if not fd then error("ghostnotes: cannot create temporary file for " .. path .. ": " .. tostring(temp)) end

  local written, write_err = uv.fs_write(fd, json, 0)
  local closed, close_err = uv.fs_close(fd)
  if not written or written ~= #json or not closed then
    uv.fs_unlink(temp)
    error("ghostnotes: cannot write " .. path .. ": " .. tostring(write_err or close_err or "short write"))
  end
  local renamed, rename_err = uv.fs_rename(temp, path)
  if not renamed then
    uv.fs_unlink(temp)
    error("ghostnotes: cannot replace " .. path .. ": " .. tostring(rename_err))
  end
end

---@return string
function M.get_global_path()
  local dir = vim.fn.stdpath("data") .. "/ghostnotes"
  if vim.fn.mkdir(dir, "p") == 0 and vim.fn.isdirectory(dir) == 0 then
    error("ghostnotes: cannot create directory " .. dir)
  end
  return dir .. "/ghostnotes.json"
end

---Return whether the note's source still exists as a file.
---@param note GhostnotesNote|GhostnotesPickerItem
---@return boolean
function M.source_exists(note)
  if type(note.bufname) ~= "string" or note.bufname == "" then return false end
  local stat = uv.fs_stat(note.bufname)
  return stat ~= nil and stat.type == "file"
end

return M
