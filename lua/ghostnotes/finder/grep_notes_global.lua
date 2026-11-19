local utils = require("ghostnotes.utils")
local picker = require("ghostnotes.finder.grep_common")
local M = {}

---Search note headlines and bodies across the global store.
function M.grep_notes_global()
  picker.open_picker({
    title = "Search ghost notes (global)",
    notes = utils.read_json(utils.get_global_path()),
    search_body = true,
  })
end

return M
