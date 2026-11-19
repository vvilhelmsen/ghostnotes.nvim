local config = require("ghostnotes.config")
local setters = require("ghostnotes.note_operations.setters")
local M = {}

local actions = {
  clear = { keymap = "clear_line", desc = "Clear ghost note", run = require("ghostnotes.note_operations.delete").clear_note_in_line },
  find = { keymap = "find_global", desc = "Find ghost notes (global)", run = require("ghostnotes.finder.find_notes_global").find_notes_global },
  find_project = { keymap = "find_local", desc = "Find ghost notes (project)", run = require("ghostnotes.finder.find_notes_project").find_notes_project },
  yank = { keymap = "yank_line", desc = "Yank ghost note", run = require("ghostnotes.note_operations.yank").yank_note_in_line },
  paste = { keymap = "paste_note", desc = "Paste ghost note", run = require("ghostnotes.note_operations.paste").paste_note_from_register },
  edit = { keymap = "edit_or_view_note", desc = "Edit ghost note", run = require("ghostnotes.note_operations.edit").edit_or_view_note },
  grep = { keymap = "grep_global", desc = "Search ghost notes (global)", run = require("ghostnotes.finder.grep_notes_global").grep_notes_global },
  grep_project = { keymap = "grep_local", desc = "Search ghost notes (project)", run = require("ghostnotes.finder.grep_notes_project").grep_notes_project },
}

local installed_maps = {}

---Register commands, legacy mappings, and buffer restoration.
function M.init()
  -- Do not remove mappings that the user replaced after the previous setup.
  for lhs, callback in pairs(installed_maps) do
    local current = vim.fn.maparg(lhs, "n", false, true)
    if current.callback == callback then pcall(vim.keymap.del, "n", lhs) end
  end
  installed_maps = {}

  vim.api.nvim_create_user_command("Ghostnotes", function(args)
    local action = actions[args.args]
    if action then
      action.run()
    else
      vim.notify("Unknown Ghostnotes command: " .. args.args, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Manage ghost notes",
    complete = function(arglead)
      local matches = {}
      for name in pairs(actions) do
        if name:sub(1, #arglead) == arglead then matches[#matches + 1] = name end
      end
      table.sort(matches)
      return matches
    end,
  })

  if config.opts.keymaps then
    for _, action in pairs(actions) do
      local lhs = config.opts.keymaps[action.keymap]
      if type(lhs) == "string" and lhs ~= "" then
        vim.keymap.set("n", lhs, action.run, { desc = action.desc })
        installed_maps[lhs] = action.run
      end
    end
  end

  local group = vim.api.nvim_create_augroup("Ghostnotes", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args) setters.apply_notes_for_buffer(args.buf) end,
    desc = "Restore ghost notes for file",
  })
  -- Lazy-loaded plugins may be configured after the file was read.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then setters.apply_notes_for_buffer(bufnr) end
  end
end

return M
