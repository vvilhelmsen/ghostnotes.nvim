local config = require("ghostnotes.config")
local utils = require("ghostnotes.utils")
local M = {}

local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local notes = {}

local function apply_notes_for_buffer(bufnr)
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
			local first_line = note.text:match("([^\n]+)") or note.text
			vim.api.nvim_buf_set_extmark(bufnr, ns, note.row, 0, {
				virt_text = { { config.opts.note_prefix .. first_line, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end
end

function M.init()
	vim.keymap.set("n", config.opts.keymaps.add, M.add_note, { desc = "Add ghost note" })
	vim.keymap.set("n", config.opts.keymaps.clear_line, M.clear_note_in_line, { desc = "Clear ghost note" })
	vim.keymap.set("n", config.opts.keymaps.find_global, M.find_notes_global, { desc = "Find ghost notes (global)" })
	vim.keymap.set("n", config.opts.keymaps.find_local, M.find_notes_project, { desc = "Find ghost notes (project)" })
	vim.keymap.set("n", config.opts.keymaps.yank_line, M.yank_note_in_line, { desc = "Yank ghost note" })
	vim.keymap.set("n", config.opts.keymaps.edit_or_view_note, M.edit_or_view_note, { desc = "View / edit ghost note" })

	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			apply_notes_for_buffer(args.buf)
		end,
		desc = "Restore ghost notes for file",
	})
end

function M.add_note()
	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local note = vim.fn.input("Ghost note: ")
	if note == "" then
		return
	end

	local new_note = {
		bufnr = bufnr,
		row = row,
		text = note,
		bufname = bufname,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	table.insert(notes, new_note)

	local first_line = note:match("([^\n]+)") or note
	vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
		virt_text = { { config.opts.note_prefix .. first_line, "Comment" } },
		virt_text_pos = "eol",
	})

	-- append (local, if in git repo)
	local git_root = utils.get_git_root()
	if git_root then
		local path = git_root .. "/.ghostnotes.json"
		local existing = utils.read_json(path)
		table.insert(existing, new_note)
		utils.write_json(path, existing)
	end

	-- append (global, always)
	local global_path = utils.get_global_path()
	local global_existing = utils.read_json(global_path)
	table.insert(global_existing, new_note)
	utils.write_json(global_path, global_existing)
end

function M.clear_note_in_line()
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

	vim.notify("Cleared ghost note", vim.log.levels.INFO)
end

function M.find_notes_project()
	local git_root = utils.get_git_root()
	if not git_root then
		vim.notify("Not inside a Git project", vim.log.levels.WARN)
		return
	end

	local path = git_root .. "/.ghostnotes.json"
	local project_notes = utils.read_json(path)
	if vim.tbl_isempty(project_notes) then
		vim.notify("No project ghost notes", vim.log.levels.INFO)
		return
	end

	vim.ui.select(project_notes, {
		prompt = "Project Ghost Notes",

		format_item = function(item)
			local name = vim.fn.fnamemodify(item.bufname, ":t")
			local headline = item.text:match("([^\n]+)") or item.text
			return string.format("%s:%d → %s", name, (item.row or 0) + 1, headline)
		end,
	}, function(choice)
		if choice and choice.bufname then
			local cur_buf = vim.api.nvim_get_current_buf()
			local cur_name = vim.api.nvim_buf_get_name(cur_buf)
			if cur_name == choice.bufname then
				-- already in buffer: just move cursor
				vim.api.nvim_win_set_cursor(0, { (choice.row or 0) + 1, 0 })
			else
				-- switch or edit buffer
				local bufnr = vim.fn.bufnr(choice.bufname, false)
				if bufnr ~= -1 then
					vim.cmd("buffer " .. bufnr)
				else
					vim.cmd("edit " .. vim.fn.fnameescape(choice.bufname))
				end
				vim.api.nvim_win_set_cursor(0, { (choice.row or 0) + 1, 0 })
			end

			-- manually apply ghost note extmark after jump
			local bufnr = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_clear_namespace(bufnr, ns, choice.row, choice.row + 1)
			local first_line = choice.text:match("([^\n]+)") or choice.text
			vim.api.nvim_buf_set_extmark(bufnr, ns, choice.row, 0, {
				virt_text = { { config.opts.note_prefix .. first_line, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end)
end

function M.find_notes_global()
	local global_path = utils.get_global_path()
	local all_notes = utils.read_json(global_path)
	if vim.tbl_isempty(all_notes) then
		vim.notify("No ghost notes in global file", vim.log.levels.INFO)
		return
	end

	vim.ui.select(all_notes, {
		prompt = "All Ghost Notes (Global)",
		format_item = function(item)
			local name = vim.fn.fnamemodify(item.bufname, ":t")
			local headline = item.text:match("([^\n]+)") or item.text
			return string.format("%s:%d → %s", name, (item.row or 0) + 1, headline)
		end,
	}, function(choice)
		if choice and choice.bufname then
			local cur_buf = vim.api.nvim_get_current_buf()
			local cur_name = vim.api.nvim_buf_get_name(cur_buf)
			if cur_name == choice.bufname then
				-- if already in buffer: move cursor, no reload
				vim.api.nvim_win_set_cursor(0, { (choice.row or 0) + 1, 0 })
			else
				-- switch to buffer if loaded, otherwise edit
				local bufnr = vim.fn.bufnr(choice.bufname, false)
				if bufnr ~= -1 then
					vim.cmd("buffer " .. bufnr)
				else
					vim.cmd("edit " .. vim.fn.fnameescape(choice.bufname))
				end
				vim.api.nvim_win_set_cursor(0, { (choice.row or 0) + 1, 0 })
			end

			-- manually apply ghost note extmark after jump
			local bufnr = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_clear_namespace(bufnr, ns, choice.row, choice.row + 1)

			vim.api.nvim_buf_set_extmark(bufnr, ns, choice.row, 0, {
				virt_text = { { config.opts.note_prefix .. choice.text, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end)
end

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

function M.edit_or_view_note()
	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local git_root = utils.get_git_root()
	local note = nil
	local global_path = utils.get_global_path()

	if git_root then
		local project_path = git_root .. "/.ghostnotes.json"
		for _, n in ipairs(utils.read_json(project_path)) do
			if n.bufname == bufname and n.row == row then
				note = vim.deepcopy(n)
			end
		end
	end
	if not note then
		for _, n in ipairs(utils.read_json(global_path)) do
			if n.bufname == bufname and n.row == row then
				note = vim.deepcopy(n)
				break
			end
		end
	end

	local max_width, lines = 60, {}
	if note then
		for line in note.text:gmatch("[^\n]+") do
			while #line > max_width do
				table.insert(lines, line:sub(1, max_width))
				line = line:sub(max_width + 1)
			end
			table.insert(lines, line)
		end
	end
	if #lines == 0 then
		lines = { "" }
	end

	local float_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(float_buf, "filetype", "markdown")

	local editor_width = vim.o.columns
	local editor_height = vim.o.lines

	local float_width = math.floor(editor_width * 0.5)
	local float_height = math.max(math.floor(editor_height * 0.75), #lines + 2)

	local win = vim.api.nvim_open_win(float_buf, true, {
		relative = "editor",
		width = float_width,
		height = float_height,
		row = math.floor((editor_height - float_height) / 2),
		col = math.floor((editor_width - float_width) / 2),
		style = "minimal",
		border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        title = " ⏎ press q to save/exit   ┃   1st line: headline   ┃   2nd+: body ",
		title_pos = "center",
	})

	local function upsert_note(text)
		-- text is a table of lines from the buffer, join with newlines
		text = table.concat(text, "\n")

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
		local first_line = text:match("([^\n]+)") or text
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
			virt_text = { { config.opts.note_prefix .. first_line, "Comment" } },
			virt_text_pos = "eol",
		})
		vim.notify(note and "Saved ghost note" or "Added ghost note", vim.log.levels.INFO)
	end

	local function delete_note()
		local function remove_note(path)
			local notes = utils.read_json(path)
			local filtered = vim.tbl_filter(function(n)
				return not (n.bufname == bufname and n.row == row)
			end, notes)
			utils.write_json(path, filtered)
		end
		if git_root then
			remove_note(git_root .. "/.ghostnotes.json")
		end
		remove_note(global_path)
		vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
		vim.notify("Deleted ghost note", vim.log.levels.INFO)
	end

	local function save_and_close()
		local new_lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
		local new_text = table.concat(new_lines, "\n")
		if new_text:match("^%s*$") then
			if note then
				delete_note()
			end
		else
			upsert_note(new_lines)
		end
		vim.api.nvim_win_close(win, true)
	end

	vim.api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"q",
		"<cmd>lua vim.api.nvim_win_close(" .. win .. ", true)<CR>",
		{ nowait = true, noremap = true, silent = true }
	)
	-- prevents leaving with escape
	vim.api.nvim_create_autocmd({ "BufLeave" }, {
		buffer = float_buf,
		once = true,
		callback = function()
			save_and_close()
		end,
	})

	vim.cmd("stopinsert")
end

return M
