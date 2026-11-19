local utils = require("ghostnotes.utils")
local picker = require("ghostnotes.finder.grep_common")
local M = {}

---Search note headlines and bodies in the current Git project.
function M.grep_notes_project()
  local root = utils.get_git_root()
  if not root then
    vim.notify("Not inside a Git project", vim.log.levels.WARN)
    return
  end
  picker.open_picker({
    title = "Search ghost notes (project)",
    notes = utils.read_json(root .. "/.ghostnotes.json"),
    search_body = true,
  })
end

return M
