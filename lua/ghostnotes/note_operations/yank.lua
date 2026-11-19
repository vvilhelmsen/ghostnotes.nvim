local storage = require("ghostnotes.storage")
local M = {}

---Copy the current line's note to register g.
---@return boolean yanked
function M.yank_note_in_line()
  local bufname = vim.api.nvim_buf_get_name(0)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local note = bufname ~= "" and storage.get(bufname, row) or nil
  if not note then
    vim.notify("No ghost note to yank", vim.log.levels.WARN)
    return false
  end
  vim.fn.setreg("g", note.text)
  vim.notify("Yanked ghost note into register g", vim.log.levels.INFO)
  return true
end

return M
