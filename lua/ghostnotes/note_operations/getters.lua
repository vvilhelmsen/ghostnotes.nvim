local M = {}
function M.get_note_headline(note)
	local first_line = note.text:match("([^\n]+)") or note.text
	if note.text:find("\n") then
		return first_line .. " [..]"
	end
	return first_line
end

return M
