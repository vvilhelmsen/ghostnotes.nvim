local utils       = require("ghostnotes.utils")
local config      = require("ghostnotes.config")
local ns          = vim.api.nvim_create_namespace(config.opts.namespace)
local path_fmt    = config.opts.path_format or ":t"
local get_head    = require("ghostnotes.note_operations.getters").get_note_headline
local live_picker = require("ghostnotes.finder.grep_common")

local M = {}

local function jump_and_mark(item)
  if not item or not item.bufname then return end
  local bufnr = vim.fn.bufnr(item.bufname, false)
  if bufnr ~= -1 then
    vim.cmd("buffer " .. bufnr)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(item.bufname))
  end
  bufnr = vim.api.nvim_get_current_buf()
  local row = (item.row or 0)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
  pcall(vim.api.nvim_win_set_cursor, 0, { row + 1, 0 })
  local display = get_head({ text = item.note_text })
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_text = { { config.opts.note_prefix .. display, "Comment" } },
    virt_text_pos = "eol",
  })
end

function M.grep_notes_project()
  local git_root = utils.get_git_root()
  if not git_root then
    vim.notify("Not inside a Git project", vim.log.levels.WARN)
    return
  end
  local path  = git_root .. "/.ghostnotes.json"
  local notes = utils.read_json(path)
  if vim.tbl_isempty(notes) then
    vim.notify("No project ghost notes", vim.log.levels.INFO)
    return
  end

  live_picker.open_picker({
    title = "Ghost Notes (Project) — live grep",
    notes = notes,
    path_format = path_fmt,
    on_confirm = jump_and_mark,
  })
end

return M
