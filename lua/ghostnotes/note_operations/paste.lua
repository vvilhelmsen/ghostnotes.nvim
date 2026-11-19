local storage = require("ghostnotes.storage")
local setters = require("ghostnotes.note_operations.setters")
local M = {}

---Create or replace the current line's note with register g.
function M.paste_note_from_register()
  local text = vim.fn.getreg("g")
  if text == "" then
    vim.notify("Register g is empty", vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" or vim.bo[bufnr].buftype ~= "" then
    vim.notify("Ghost notes require a named file buffer", vim.log.levels.WARN)
    return
  end
  local note = {
    row = vim.api.nvim_win_get_cursor(0)[1] - 1,
    text = text,
    bufname = bufname,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  storage.upsert(note)
  setters.mark_note(bufnr, note)
  vim.notify("Pasted ghost note from register g", vim.log.levels.INFO)
end

return M
