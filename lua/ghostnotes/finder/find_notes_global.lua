local utils = require("ghostnotes.utils")
local picker = require("ghostnotes.finder.grep_common")
local M = {}

---Find notes across the global store.
function M.find_notes_global()
  picker.open_picker({ title = "Ghost notes (global)", notes = utils.read_json(utils.get_global_path()) })
end

return M
