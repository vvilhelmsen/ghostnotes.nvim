local utils = require("ghostnotes.utils")
local config = require("ghostnotes.config")
local yank = require("ghostnotes.note_operations.yank")
local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local M = {}

function M.clear_note_in_line()
	yank.yank_note_in_line()

	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)

	-- remove (local)
	local git_root = utils.get_git_root()
	if git_root then
		local path = git_root .. "/.ghostnotes.json"
		local existing = utils.read_json(path)
		local new_notes = vim.tbl_filter(function(note)
			return not (note.bufname == bufname and note.row == row)
		end, existing)
		utils.write_json(path, new_notes)
	end

	-- remove (global)
	local global_path = utils.get_global_path()
	local global_existing = utils.read_json(global_path)
	local new_global_notes = vim.tbl_filter(function(note)
		return not (note.bufname == bufname and note.row == row)
	end, global_existing)
	utils.write_json(global_path, new_global_notes)

	vim.notify("Cleared ghost note (and yanked to register g)", vim.log.levels.INFO)
end

return M
