local M = {}
M.opts = {
	keymaps = {
		clear_line = "<leader>gnc",
		find_global = "<leader>gnf",
		find_local = "<leader>gnF",
		yank_line = "<leader>gny",
		edit_or_view_note = "<leader>gne",
		grep_global = "<leader>gng",
		grep_local = "<leader>gnG",
	},
	namespace = "ghostnotes",
	note_prefix = "👻 ",

    -- Some modifiers:
    -- :p   - Absolute path
    -- :.   - Relative to current directory
    -- :~   - Relative to home directory
    -- :h   - Head (directory portion, /foo/bar)
    -- :t   - Tail (filename only, file.txt) - default 
    -- :r   - Root (file without extension, file)
    -- :e   - Extension only (txt)
    -- You can chain modifiers, e.g. ":t:r" (filename without extension)
	path_format = ":t",
}

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})
end

return M
