local config = require("ghostnotes.config")
local M = {}

local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local notes = {}

function M.init()
  vim.keymap.set("n", config.opts.keymaps.add, M.add_note, { desc = "Add ghost note" })
  vim.keymap.set("n", config.opts.keymaps.clear, M.clear_notes, { desc = "Clear ghost notes" })
  vim.keymap.set("n", config.opts.keymaps.find, M.find_note, { desc = "Find ghost notes" })
end

function M.add_note()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local note = vim.fn.input("Ghost note: ")
  if note == "" then return end

  table.insert(notes, { bufnr = bufnr, row = row, text = note })
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_text = { { "👻 " .. note, "Comment" } },
    virt_text_pos = "eol",
  })
end

function M.clear_notes()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  notes = {}
  vim.notify("Cleared all ghost notes", vim.log.levels.INFO)
end

function M.find_note()
  if vim.tbl_isempty(notes) then
    vim.notify("No ghost notes", vim.log.levels.INFO)
    return
  end

  vim.ui.select(notes, {
    prompt = "Ghost Notes",
    format_item = function(item)
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(item.bufnr), ":t")
      return string.format("%s:%d → %s", name, item.row + 1, item.text)
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_set_current_buf(choice.bufnr)
      vim.api.nvim_win_set_cursor(0, { choice.row + 1, 0 })
    end
  end)
end

return M
