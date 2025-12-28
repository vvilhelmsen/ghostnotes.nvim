local utils = require("ghostnotes.utils")
local config = require("ghostnotes.config")
local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local get_note_headline = require("ghostnotes.note_operations.getters").get_note_headline

local M = {}

function M.paste_note_from_register()
	local text = vim.fn.getreg("g")
	if not text or text == "" then
		vim.notify("Register 'g' is empty", vim.log.levels.WARN)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local git_root = utils.get_git_root()
	local global_path = utils.get_global_path()

	local new_note = {
		bufnr = bufnr,
		row = row,
		text = text,
		bufname = bufname,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	local function upsert(path)
		local notes = utils.read_json(path)
		local found = false
		for i, n in ipairs(notes) do
			if n.bufname == bufname and n.row == row then
				notes[i] = new_note
				found = true
				break
			end
		end
		if not found then
			table.insert(notes, new_note)
		end
		utils.write_json(path, notes)
	end

	if git_root then
		upsert(git_root .. "/.ghostnotes.json")
	end
	upsert(global_path)

	vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
	local display_text = get_note_headline(new_note)
	vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
		virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
		virt_text_pos = "eol",
	})

	vim.notify("Pasted ghost note from register 'g'", vim.log.levels.INFO)
end

return M
