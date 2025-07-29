local M = {}

M.opts = {
  keymaps = {
    add = "<leader>åc",
    clear = "<leader>åk",
    find_global = "<leader>åf",
    find_local = "<leader>åF",
  },
  namespace = "ghostnotes",
}

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})
end

return M
