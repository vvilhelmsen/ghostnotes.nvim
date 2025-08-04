local config = require("ghostnotes.config")
local utils = require("ghostnotes.utils")
local yank = require("ghostnotes.note_operations.yank")
local delete = require("ghostnotes.note_operations.delete")
local edit = require("ghostnotes.note_operations.edit")
local find_global = require("ghostnotes.finder.find_notes_global")
local find_project = require("ghostnotes.finder.find_notes_project")
local setters = require("ghostnotes.note_operations.setters")

local M = {}

function M.init()
    vim.keymap.set("n", config.opts.keymaps.clear_line, delete.clear_note_in_line, { desc = "Clear ghost note" })
    vim.keymap.set("n", config.opts.keymaps.find_global, find_global.find_notes_global, { desc = "Find ghost notes (global)" })
    vim.keymap.set("n", config.opts.keymaps.find_local, find_project.find_notes_project, { desc = "Find ghost notes (project)" })
    vim.keymap.set("n", config.opts.keymaps.yank_line, yank.yank_note_in_line, { desc = "Yank ghost note" })
    vim.keymap.set("n", config.opts.keymaps.edit_or_view_note, edit.edit_or_view_note, { desc = "View / edit ghost note" })

    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
            setters.apply_notes_for_buffer(args.buf)
        end,
        desc = "Restore ghost notes for file",
    })
end

return M
