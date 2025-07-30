local M = {}
M.opts = {
	keymaps = {
		add = "<leader>gna",
		clear_line = "<leader>gnc",
		find_global = "<leader>gnf",
		find_local = "<leader>gnF",
		edit_line = "<leader>gne",
        yank_line = "<leader>gny",
	},
	namespace = "ghostnotes",
    note_prefix = "👻 ",
}

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})
end

return M
