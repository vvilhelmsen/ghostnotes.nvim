local utils = require("ghostnotes.utils")
local M = {}

function M.yank_note_in_line()
	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local git_root = utils.get_git_root()
	local note_text = nil

	if git_root then
		local project_path = git_root .. "/.ghostnotes.json"
		local notes = utils.read_json(project_path)
		for _, note in ipairs(notes) do
			if note.bufname == bufname and note.row == row then
				note_text = note.text
				break
			end
		end
	end

	if not note_text then
		local global_path = utils.get_global_path()
		local notes = utils.read_json(global_path)
		for _, note in ipairs(notes) do
			if note.bufname == bufname and note.row == row then
				note_text = note.text
				break
			end
		end
	end

	if note_text then
		vim.fn.setreg("+", note_text)
		vim.notify("Yanked ghost note", vim.log.levels.INFO)
	else
		vim.notify("No ghost note to yank", vim.log.levels.WARN)
	end
end

return M
