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
			vim.api.nvim_buf_set_extmark(bufnr, ns, note.row, 0, {
				virt_text = { { config.opts.note_prefix .. note.text, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end
end

function M.edit_note_in_line()
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1

    local git_root = utils.get_git_root()
    local note_to_edit = nil
    local project_path, global_path = nil, utils.get_global_path()

    -- check project notes first
    if git_root then
        project_path = git_root .. "/.ghostnotes.json"
        local notes = utils.read_json(project_path)
        for _, note in ipairs(notes) do
            if note.bufname == bufname and note.row == row then
                note_to_edit = { note = note, path = project_path, index = _ }
                break
            end
        end
    end

    -- If not found in project, check global
    if not note_to_edit then
        local notes = utils.read_json(global_path)
        for _, note in ipairs(notes) do
            if note.bufname == bufname and note.row == row then
                note_to_edit = { note = note, path = global_path, index = _ }
                break
            end
        end
    end

    if not note_to_edit then
        vim.notify("No ghost note found on this line", vim.log.levels.WARN)
        return
    end

    local new_text = vim.fn.input("Edit ghost note: ", note_to_edit.note.text)
    if new_text == "" or new_text == note_to_edit.note.text then
        return
    end

    -- Update in both files
    local function update_note(path)
        local notes = utils.read_json(path)
        local updated = false
        for i, note in ipairs(notes) do
            if note.bufname == bufname and note.row == row then
                note.text = new_text
                note.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                notes[i] = note
                updated = true
            end
        end
        if updated then
            utils.write_json(path, notes)
        end
        return updated
    end

    if project_path then update_note(project_path) end
    update_note(global_path)

    -- Redraw extmark
    vim.api.nvim_buf_clear_namespace(bufnr, ns, row, row + 1)
    local all_notes = {}
    if project_path then
        all_notes = utils.read_json(project_path)
    else
        all_notes = utils.read_json(global_path)
    end
    for _, note in ipairs(all_notes) do
        if note.bufname == bufname and note.row == row then
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
				virt_text = { { config.opts.note_prefix .. note.text, "Comment" } },
                virt_text_pos = "eol",
            })
        end
    end

    vim.notify("Edited ghost note on this line", vim.log.levels.INFO)
end

function M.init()
	vim.keymap.set("n", config.opts.keymaps.add, M.add_note, { desc = "Add ghost note" })
	vim.keymap.set("n", config.opts.keymaps.clear_line, M.clear_note_in_line, { desc = "Clear ghost note on line" })
	vim.keymap.set("n", config.opts.keymaps.find_global, M.find_notes_global, { desc = "Find ghost notes (global)" })
	vim.keymap.set("n", config.opts.keymaps.find_local, M.find_notes_project, { desc = "Find ghost notes (project)" })
	vim.keymap.set(
		"n",
		config.opts.keymaps.edit_line or "<leader>gne",
		M.edit_note_in_line,
		{ desc = "Edit ghost note on current line" }
	)

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

	vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
		virt_text = { { config.opts.note_prefix .. note, "Comment" } },
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

	vim.notify("Cleared ghost note on this line", vim.log.levels.INFO)
end

function M.find_notes_project()
	utils.find_notes_project()
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
			local name = vim.fn.fnamemodify(item.bufname or "?", ":t")
			return string.format("%s:%d → %s", name, (item.row or 0) + 1, item.text)
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

return M
