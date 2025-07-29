local M = {}

M.opts = {
  keymaps = {
    add = "<leader>gna",
    clear_line = "<leader>gnc",
    find_global = "<leader>gnf",
    find_local = "<leader>gnF",
  },
  namespace = "ghostnotes",
}

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})
end

return M
