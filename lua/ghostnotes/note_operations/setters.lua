local utils = require("ghostnotes.utils")
local config = require("ghostnotes.config")
local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local get_note_headline = require("ghostnotes.note_operations.getters").get_note_headline
local M = {}

function M.apply_notes_for_buffer(bufnr)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local git_root = utils.get_git_root()
	local path, all_notes

	if git_root then
		path = git_root .. "/.ghostnotes.json"
		all_notes = utils.read_json(path)
	else
		path = utils.get_global_path()
		all_notes = utils.read_json(path)
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for _, note in ipairs(all_notes) do
		if note.bufname == bufname then
			local display_text = get_note_headline(note)
			vim.api.nvim_buf_set_extmark(bufnr, ns, note.row, 0, {
				virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end
end

return M
