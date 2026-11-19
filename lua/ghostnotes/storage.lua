local utils = require("ghostnotes.utils")

---@class GhostnotesNote
---@field bufname string Absolute source file path
---@field row integer Zero-based source line
---@field text string
---@field timestamp? string
---@field bufnr? integer Legacy buffer number, not used to identify a note

local M = {}

---@param bufname string
---@return string?
function M.project_path(bufname)
  local root = utils.get_git_root(bufname)
  return root and (root .. "/.ghostnotes.json") or nil
end

---@param notes GhostnotesNote[]
---@param bufname string
---@param row integer
---@return GhostnotesNote?
local function find(notes, bufname, row)
  for _, note in ipairs(notes) do
    if note.bufname == bufname and note.row == row then return note end
  end
end

---Project notes take precedence over the global index when both exist.
---@param bufname string
---@param row integer
---@return GhostnotesNote?
function M.get(bufname, row)
  local project = M.project_path(bufname)
  return (project and find(utils.read_json(project), bufname, row))
    or find(utils.read_json(utils.get_global_path()), bufname, row)
end

---@param bufname string
---@return GhostnotesNote[]
function M.for_buffer(bufname)
  local by_row = {}
  local function add(notes)
    for _, note in ipairs(notes) do
      if type(note) == "table" and note.bufname == bufname and type(note.row) == "number"
        and note.row >= 0 and note.row % 1 == 0 and type(note.text) == "string" then
        by_row[note.row] = note
      end
    end
  end
  add(utils.read_json(utils.get_global_path()))
  local project = M.project_path(bufname)
  if project then add(utils.read_json(project)) end
  local notes = {}
  for _, note in pairs(by_row) do notes[#notes + 1] = note end
  table.sort(notes, function(a, b) return a.row < b.row end)
  return notes
end

---Read both stores before changing either, so malformed JSON cannot be overwritten.
---@param bufname string
---@return {path: string, notes: GhostnotesNote[]}[]
local function stores(bufname)
  local result = {}
  local project = M.project_path(bufname)
  if project then result[#result + 1] = { path = project, notes = utils.read_json(project) } end
  local global = utils.get_global_path()
  result[#result + 1] = { path = global, notes = utils.read_json(global) }
  return result
end

---@param note GhostnotesNote
function M.upsert(note)
  for _, store in ipairs(stores(note.bufname)) do
    local replaced = false
    for i, existing in ipairs(store.notes) do
      if existing.bufname == note.bufname and existing.row == note.row then
        store.notes[i] = note
        replaced = true
        break
      end
    end
    if not replaced then table.insert(store.notes, note) end
    utils.write_json(store.path, store.notes)
  end
end

---@param bufname string
---@param row integer
function M.delete(bufname, row)
  for _, store in ipairs(stores(bufname)) do
    local filtered = vim.tbl_filter(function(note)
      return note.bufname ~= bufname or note.row ~= row
    end, store.notes)
    if #filtered ~= #store.notes then utils.write_json(store.path, filtered) end
  end
end

---@param note GhostnotesNote
---@param new_row integer
function M.move(note, new_row)
  for _, store in ipairs(stores(note.bufname)) do
    local existing = find(store.notes, note.bufname, note.row)
    if existing then
      existing.row = new_row
      utils.write_json(store.path, store.notes)
    end
  end
end

return M
