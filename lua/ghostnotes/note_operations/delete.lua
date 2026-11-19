local storage = require("ghostnotes.storage")
local setters = require("ghostnotes.note_operations.setters")
local yank = require("ghostnotes.note_operations.yank")
local M = {}

---Yank and delete the current line's note, if present.
function M.clear_note_in_line()
  if not yank.yank_note_in_line() then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  storage.delete(bufname, row)
  vim.api.nvim_buf_clear_namespace(bufnr, setters.namespace(), row, row + 1)
  vim.notify("Cleared ghost note (yanked to register g)", vim.log.levels.INFO)
end

return M
