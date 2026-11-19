local M = {}

---@param user_opts? GhostnotesSetupOptions
function M.setup(user_opts)
  local config = require("ghostnotes.config")
  local previous_namespace = config.opts.namespace
  config.setup(user_opts)
  if previous_namespace ~= config.opts.namespace then
    local old_ns = vim.api.nvim_create_namespace(previous_namespace)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, old_ns, 0, -1)
      end
    end
  end
  require("ghostnotes.core").init()
  if user_opts and type(user_opts.keymaps) == "table" then
    vim.notify("Ghostnotes keymaps are deprecated; use :Ghostnotes commands and your own mappings. Set keymaps = false to disable the defaults.", vim.log.levels.WARN)
  end
end

return M
