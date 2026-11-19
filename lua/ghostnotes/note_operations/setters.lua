local config = require("ghostnotes.config")
local storage = require("ghostnotes.storage")
local get_headline = require("ghostnotes.note_operations.getters").get_note_headline
local M = {}

---@return integer
function M.namespace()
  return vim.api.nvim_create_namespace(config.opts.namespace)
end

---@param bufnr integer
---@param note GhostnotesNote
function M.mark_note(bufnr, note)
  if note.row < 0 or note.row >= vim.api.nvim_buf_line_count(bufnr) then return end
  local ns = M.namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, note.row, note.row + 1)
  vim.api.nvim_buf_set_extmark(bufnr, ns, note.row, 0, {
    virt_text = { { config.opts.note_prefix .. get_headline(note), "Comment" } },
    virt_text_pos = "eol",
  })
end

---@param bufnr integer
function M.apply_notes_for_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then return end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then return end
  local notes = storage.for_buffer(bufname)
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace(), 0, -1)
  for _, note in ipairs(notes) do M.mark_note(bufnr, note) end
end

return M
