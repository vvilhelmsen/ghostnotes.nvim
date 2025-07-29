local config = require("ghostnotes.config")
local utils = require("ghostnotes.utils")

local M = {}

local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local notes = {}

function M.init()
  vim.keymap.set("n", config.opts.keymaps.add, M.add_note, { desc = "Add ghost note" })
  vim.keymap.set("n", config.opts.keymaps.clear, M.clear_notes, { desc = "Clear ghost notes (buffer)" })
  vim.keymap.set("n", config.opts.keymaps.find_global, M.find_notes_global, { desc = "Find ghost notes (global)" })
end

function M.add_note()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local note = vim.fn.input("Ghost note: ")
  if note == "" then return end

  local new_note = {
    bufnr = bufnr,
    row = row,
    text = note,
    bufname = bufname,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  table.insert(notes, new_note)

  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_text = { { "👻 " .. note, "Comment" } },
    virt_text_pos = "eol",
  })

  -- Persist to .ghostnotes.json if inside a git repo
  local git_root = utils.get_git_root()
  if git_root then
    local path = git_root .. "/.ghostnotes.json"
    local existing = utils.read_json(path)
    table.insert(existing, new_note)
    utils.write_json(path, existing)
  end
end

function M.clear_notes()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  notes = {}
  vim.notify("Cleared all ghost notes", vim.log.levels.INFO)
end

function M.find_notes_global()
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
