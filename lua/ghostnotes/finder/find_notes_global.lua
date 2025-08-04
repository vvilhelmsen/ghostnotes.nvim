local utils = require("ghostnotes.utils")
local config = require("ghostnotes.config")
local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local get_note_headline = require("ghostnotes.note_operations.getters").get_note_headline


local M = {}

function M.find_notes_global()
	local global_path = utils.get_global_path()
	local all_notes = utils.read_json(global_path)
	if vim.tbl_isempty(all_notes) then
		vim.notify("No ghost notes in global file", vim.log.levels.INFO)
		return
	end

	local notes_with_file = vim.tbl_map(function(note)
		note.file = get_note_headline(note)
		return note
	end, all_notes)

	Snacks.picker.pick({
		items = notes_with_file,
		prompt = "> ",
		format_item = function(item)
			local name = item.file
			local headline = get_note_headline(item)
			return string.format("%s:%d → %s", name, (item.row or 0) + 1, headline)
		end,
		on_choice = function(choice)
			if choice and choice.bufname then
				local cur_buf = vim.api.nvim_get_current_buf()
				local cur_name = vim.api.nvim_buf_get_name(cur_buf)

				-- Open the buffer if needed
				if cur_name ~= choice.bufname then
					local bufnr = vim.fn.bufnr(choice.bufname, false)
					if bufnr ~= -1 then
						vim.cmd("buffer " .. bufnr)
					else
						vim.cmd("edit " .. vim.fn.fnameescape(choice.bufname))
					end
				end

				-- in the target buffer
				local bufnr = vim.api.nvim_get_current_buf()
				local last_line = vim.api.nvim_buf_line_count(bufnr)
				local target_row = (choice.row or 0)

				-- clear the old extmark
				vim.api.nvim_buf_clear_namespace(bufnr, ns, target_row, target_row + 1)

				if target_row >= 0 and target_row < last_line then
					-- Original position exists: move cursor there
					local ok, err = pcall(vim.api.nvim_win_set_cursor, 0, { target_row + 1, 0 })
					if not ok then
						vim.notify("Failed to set cursor: " .. err, vim.log.levels.WARN)
					end

					-- Apply extmark at the original position
					local display_text = get_note_headline(choice)
					vim.api.nvim_buf_set_extmark(bufnr, ns, target_row, 0, {
						virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
						virt_text_pos = "eol",
					})
				else
					-- Try to find a new position
					local existing_notes = utils.read_json(global_path)
					local used_lines = {}

					-- Collect all rows that already have notes in this buffer
					for _, note in ipairs(existing_notes) do
						if note.bufname == choice.bufname then
							used_lines[note.row] = true
						end
					end

					-- find an available line
					local new_row = nil
					for i = last_line - 1, 0, -1 do
						if not used_lines[i] then
							new_row = i
							break
						end
					end

					if new_row ~= nil then
						-- Found available line, move note there
						vim.notify(
							"Line "
								.. (target_row + 1)
								.. " doesn't exist; moving note to last available line: "
								.. (new_row + 1),
							vim.log.levels.INFO
						)

						-- Update note position in storage
						local git_root = utils.get_git_root()
						if git_root then
							local path = git_root .. "/.ghostnotes.json"
							local project_notes = utils.read_json(path)
							for i, note in ipairs(project_notes) do
								if note.bufname == choice.bufname and note.row == target_row then
									project_notes[i].row = new_row
									utils.write_json(path, project_notes)
									break
								end
							end
						end

						-- Update in global notes
						for i, note in ipairs(existing_notes) do
							if note.bufname == choice.bufname and note.row == target_row then
								existing_notes[i].row = new_row
								utils.write_json(global_path, existing_notes)
								break
							end
						end

						-- Move cursor to new position
						local ok, err = pcall(vim.api.nvim_win_set_cursor, 0, { new_row + 1, 0 })
						if not ok then
							vim.notify("Failed to set cursor: " .. err, vim.log.levels.WARN)
						end

						-- Apply extmark at the new position
						local display_text = get_note_headline(choice)
						vim.api.nvim_buf_set_extmark(bufnr, ns, new_row, 0, {
							virt_text = { { config.opts.note_prefix .. display_text, "Comment" } },
							virt_text_pos = "eol",
						})
					else
						vim.notify("No available space for ghost note. Copied note to clipboard", vim.log.levels.INFO)
						vim.fn.setreg("+", choice.text)
					end
				end
			end
		end,
	})
end

return M
