local M = {}

function M.setup(user_opts)
  require("ghostnotes.config").setup(user_opts)
  require("ghostnotes.core").init()
end

return M
