local config = require("ghostnotes.config")
local utils = require("ghostnotes.utils")

local M = {}

local ns = vim.api.nvim_create_namespace(config.opts.namespace)
local notes = {}

local function apply_notes_for_buffer(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local git_root = utils.get_git_root()
    if not git_root then
        return
    end
    local path = git_root .. "/.ghostnotes.json"
    local all_notes = utils.read_json(path)

    -- Clear previous ghost notes for this buffer/namespace
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    for _, note in ipairs(all_notes) do
        if note.bufname == bufname then
            vim.api.nvim_buf_set_extmark(bufnr, ns, note.row, 0, {
                virt_text = { { "👻 " .. note.text, "Comment" } },
                virt_text_pos = "eol",
            })
        end
    end
end

function M.init()
	vim.keymap.set("n", config.opts.keymaps.add, M.add_note, { desc = "Add ghost note" })
	vim.keymap.set("n", config.opts.keymaps.clear, M.clear_notes, { desc = "Clear ghost notes (buffer)" })
	vim.keymap.set("n", config.opts.keymaps.find_global, M.find_notes_global, { desc = "Find ghost notes (global)" })
    vim.keymap.set("n", config.opts.keymaps.find_local, M.find_notes_project, { desc = "Find ghost notes (project)" })

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
		virt_text = { { "👻 " .. note, "Comment" } },
		virt_text_pos = "eol",
	})

	local git_root = utils.get_git_root()
	if git_root then
		local path = git_root .. "/.ghostnotes.json"
		local existing = utils.read_json(path)
		table.insert(existing, new_note)
		utils.write_json(path, existing)
	end

	-- Append to global file
	local global_path = utils.get_global_path()
	local global_existing = utils.read_json(global_path)
	table.insert(global_existing, new_note)
	utils.write_json(global_path, global_existing)
end

function M.clear_notes()
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	notes = {}
	vim.notify("Cleared all ghost notes", vim.log.levels.INFO)
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
      vim.cmd("edit " .. vim.fn.fnameescape(choice.bufname))
      vim.api.nvim_win_set_cursor(0, { (choice.row or 0) + 1, 0 })
    end
  end)
end

return M
