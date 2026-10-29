local utils = require("ghostnotes.utils")
local picker = require("ghostnotes.finder.grep_common")
local M = {}

---Find notes in the current working directory's Git project.
function M.find_notes_project()
  local root = utils.get_git_root()
  if not root then
    vim.notify("Not inside a Git project", vim.log.levels.WARN)
    return
  end
  picker.open_picker({ title = "Ghost notes (project)", notes = utils.read_json(root .. "/.ghostnotes.json") })
end

return M
