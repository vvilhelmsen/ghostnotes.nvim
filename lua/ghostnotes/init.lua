local M = {}

function M.config(user_opts)
  require("ghostnotes.config").setup(user_opts)
  require("ghostnotes.core").init()
end

return M
