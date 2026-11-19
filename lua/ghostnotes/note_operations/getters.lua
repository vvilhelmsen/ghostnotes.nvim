local M = {}

---@param note GhostnotesNote
---@return string
function M.get_note_headline(note)
  local text = note.text or ""
  local first_line = text:match("^[^\n]*") or ""
  return first_line .. (text:find("\n", 1, true) and " [..]" or "")
end

return M
