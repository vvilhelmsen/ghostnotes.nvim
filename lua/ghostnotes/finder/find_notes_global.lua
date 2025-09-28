local utils = require("ghostnotes.utils")
local config = require("ghostnotes.config")
local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local path_format = config.opts.path_format or ":t"
local get_note_headline = require("ghostnotes.note_operations.getters").get_note_headline
local build_items = require("ghostnotes.finder.common").build_items

local M = {}

local function handle_note_selection(note)
	if not note or not note.bufname then
		return
	end

	local bufnr = vim.fn.bufnr(note.bufname, false)
	if bufnr ~= -1 then
		vim.cmd("buffer " .. bufnr)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(note.bufname))
	end

	bufnr = vim.api.nvim_get_current_buf()
	local last_line = vim.api.nvim_buf_line_count(bufnr)
	local target_row = (note.row or 0)
    local note_text = note.note_text or note.text

	vim.api.nvim_buf_clear_namespace(bufnr, ns, target_row, target_row + 1)

	if target_row >= 0 and target_row < last_line then
		-- Move cursor to note position
		pcall(vim.api.nvim_win_set_cursor, 0, { target_row + 1, 0 })

		-- Apply extmark
		local display_text = get_note_headline({ text = note_text })
		vim.api.nvim_buf_set_extmark(bufnr, ns, target_row, 0, {
			virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
			virt_text_pos = "eol",
		})

	else
		-- Handle the case where the line doesn't exist anymore
		local global_path = utils.get_global_path()
		local existing_notes = utils.read_json(global_path)
		local used_lines = {}

		for _, n in ipairs(existing_notes) do
			if n.bufname == note.bufname then
				used_lines[n.row] = true
			end
		end

		local new_row = nil
		for i = last_line - 1, 0, -1 do
			if not used_lines[i] then
				new_row = i
				break
			end
		end

		if new_row ~= nil then
			vim.notify(
				"Line " .. (target_row + 1) .. " doesn't exist; moving note to line: " .. (new_row + 1),
				vim.log.levels.INFO
			)

			-- Update (project notes)
			local git_root = utils.get_git_root()
			if git_root then
				local path = git_root .. "/.ghostnotes.json"
				local project_notes = utils.read_json(path)
				for i, n in ipairs(project_notes) do
					if n.bufname == note.bufname and n.row == target_row then
						project_notes[i].row = new_row
						utils.write_json(path, project_notes)
						break
					end
				end
			end

			-- Update (global notes)
			for i, n in ipairs(existing_notes) do
				if n.bufname == note.bufname and n.row == target_row then
					existing_notes[i].row = new_row
					utils.write_json(global_path, existing_notes)
					break
				end
			end

			pcall(vim.api.nvim_win_set_cursor, 0, { new_row + 1, 0 })
			local display_text = get_note_headline({ text = note_text })
			vim.api.nvim_buf_set_extmark(bufnr, ns, new_row, 0, {
				virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
				virt_text_pos = "eol",
			})
		else
			vim.notify("No available space for ghost note. Copied note to clipboard", vim.log.levels.INFO)
			vim.fn.setreg("+", note_text)
		end
	end
end

function M.find_notes_global()
	local global_path = utils.get_global_path()
	local all_notes = utils.read_json(global_path)
	local items = build_items(all_notes, path_format)
	if vim.tbl_isempty(all_notes) then
		vim.notify("No ghost notes in global file", vim.log.levels.INFO)
		return
	end

	if Snacks and Snacks.picker then
		Snacks.picker.pick({
			items = items,
			prompt = "> ",
			title = "Ghost Notes (Global)",
			format = "text",
			confirm = function(picker, item)
				if item then
					picker:close()
					handle_note_selection(item)
				end
			end,
			preview = function(ctx)
				ctx.preview:reset()

				local lines = {}
				if ctx.item.note_text then
					for line in ctx.item.note_text:gmatch("([^\n]*)\n?") do
						table.insert(lines, line)
					end
				end

				ctx.preview:set_lines(lines)
				local name = vim.fn.fnamemodify(ctx.item.bufname, ":t")
				ctx.preview:set_title(string.format("%s (line %d)", name, (ctx.item.row or 0) + 1))
				ctx.preview:highlight({ ft = "markdown" })
			end,
		})
	else
		-- Try to use Telescope if available
		local status_ok, telescope = pcall(require, "telescope")
		if status_ok then
			local pickers = require("telescope.pickers")
			local finders = require("telescope.finders")
			local conf = require("telescope.config").values
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")

      local make_display = require("ghostnotes.finder.common").tel_create_displayer(items)
      local note_previewer = require("ghostnotes.finder.common").tel_previewer()

			pickers
				.new({}, {
					prompt_title = "Ghost Notes (Global)",
					finder = finders.new_table({
						results = items,
            entry_maker = function(it)
              return {
                value   = it,
                display = make_display,
                ordinal = it.display
              }
        end,
					}),
					sorter = conf.generic_sorter({}),
					previewer = note_previewer,
					attach_mappings = function(prompt_bufnr, map)
						actions.select_default:replace(function()
							local selection = action_state.get_selected_entry()
							actions.close(prompt_bufnr)
							handle_note_selection(selection.value)
						end)
						return true
					end,
				})
				:find()
		else
		    -- Fallback to vim.ui.select
			vim.ui.select(all_notes, {
				prompt = "Ghost Notes (Global)",
				format_item = function(item)
					local name = vim.fn.fnamemodify(item.bufname, ":t")
					local headline = get_note_headline(item)
					return string.format("%s:%d → %s", name, (item.row or 0) + 1, headline)
				end,
			}, handle_note_selection)
		end
	end
end

return M
