local root = vim.env.GHOSTNOTES_TEST_WORK
local ghostnotes = require("ghostnotes")
local utils = require("ghostnotes.utils")
local storage = require("ghostnotes.storage")
local common = require("ghostnotes.finder.common")
local setters = require("ghostnotes.note_operations.setters")
local messages = {}
vim.notify = function(message, level) messages[#messages + 1] = { message, level } end

local function eq(expected, actual)
  assert(vim.deep_equal(expected, actual), ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
end

local function test(name, run)
  local ok, err = xpcall(run, debug.traceback)
  if not ok then error(name .. "\n" .. err) end
  print("PASS " .. name)
end

local function git_init(path)
  vim.fn.mkdir(path, "p")
  vim.fn.system({ "git", "init", "-q", path })
  assert(vim.v.shell_error == 0, "git init failed")
end

local project = root .. "/project one"
local other_project = root .. "/project two"
git_init(project)
git_init(other_project)
local file = project .. "/notes | name.lua"
vim.fn.writefile({ "one", "two", "three", "four" }, file)
vim.cmd("cd " .. vim.fn.fnameescape(project))
vim.cmd("edit " .. vim.fn.fnameescape(file))

test("setup, commands, completion and repeat setup", function()
  ghostnotes.setup()
  assert(vim.fn.maparg("<leader>gne", "n") ~= "")
  assert(vim.tbl_contains(vim.fn.getcompletion("Ghostnotes gr", "cmdline"), "grep_project"))
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
  eq("", vim.fn.maparg("<leader>gne", "n"))
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
  eq(1, #vim.api.nvim_get_autocmds({ group = "Ghostnotes", event = "BufReadPost" }))
end)

test("repeat setup preserves mappings replaced by the user", function()
  ghostnotes.setup()
  local user_callback = function() end
  vim.keymap.set("n", "<leader>gne", user_callback)
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
  eq(user_callback, vim.fn.maparg("<leader>gne", "n", false, true).callback)
  vim.keymap.del("n", "<leader>gne")
end)

test("edit, multiple writes, empty deletion and trailing newlines", function()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("Ghostnotes edit")
  local float = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "Headline", "body", "", "last", "" })
  vim.cmd("write")
  eq("Headline\nbody\n\nlast\n", storage.get(file, 1).text)
  eq(1, #vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(file), setters.namespace(), 0, -1, {}))
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "Changed", "body" })
  vim.cmd("write")
  eq("Changed\nbody", storage.get(file, 1).text)
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "" })
  vim.cmd("write")
  eq(nil, storage.get(file, 1))
  vim.cmd("close")
end)

test("autosave, yank, paste and clear", function()
  vim.cmd("Ghostnotes edit")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Auto", "saved" })
  vim.cmd("normal q")
  eq("Auto\nsaved", storage.get(file, 1).text)
  vim.cmd("Ghostnotes yank")
  eq("Auto\nsaved", vim.fn.getreg("g"))
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.cmd("Ghostnotes paste")
  eq("Auto\nsaved", storage.get(file, 2).text)
  vim.cmd("Ghostnotes clear")
  eq(nil, storage.get(file, 2))
  eq("Auto\nsaved", vim.fn.getreg("g"))
end)

test("leaving the editor saves the note", function()
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.cmd("Ghostnotes edit")
  local float = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "Saved on leave" })
  vim.cmd("wincmd p")
  eq("Saved on leave", storage.get(file, 3).text)
  vim.api.nvim_win_close(win, true)
  storage.delete(file, 3)
  setters.apply_notes_for_buffer(vim.api.nvim_get_current_buf())
end)

test("autowrite can be disabled", function()
  ghostnotes.setup({ keymaps = false, autowrite = false, picker = { provider = "select" } })
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.cmd("Ghostnotes edit")
  local float = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "Manual save" })
  vim.cmd("wincmd p")
  eq(nil, storage.get(file, 3))
  vim.api.nvim_set_current_win(win)
  local closed = pcall(vim.cmd, "close")
  assert(not closed and vim.api.nvim_buf_is_valid(float) and vim.bo[float].modified,
    "closing an unsaved note must not discard it")
  vim.cmd("write")
  eq("Manual save", storage.get(file, 3).text)
  vim.cmd("close")
  storage.delete(file, 3)
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
end)

test("multiple editors for the same line have distinct buffers", function()
  ghostnotes.setup({ keymaps = false, autowrite = false, picker = { provider = "select" } })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("Ghostnotes edit")
  local first = vim.api.nvim_get_current_win()
  local first_name = vim.api.nvim_buf_get_name(0)
  vim.cmd("wincmd p")
  vim.cmd("Ghostnotes edit")
  local second = vim.api.nvim_get_current_win()
  assert(first_name ~= vim.api.nvim_buf_get_name(0))
  vim.api.nvim_win_close(second, true)
  vim.api.nvim_win_close(first, true)
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
end)

test("project is determined by source file, not current directory", function()
  vim.cmd("cd " .. vim.fn.fnameescape(other_project))
  eq(project, utils.get_git_root(file))
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.fn.setreg("g", "Other directory")
  vim.cmd("Ghostnotes paste")
  assert(vim.fn.filereadable(other_project .. "/.ghostnotes.json") == 0)
  assert(storage.get(file, 2))
  vim.cmd("edit!")
  eq(2, #vim.api.nvim_buf_get_extmarks(0, setters.namespace(), 0, -1, {}))
end)

test("global notes still work when Git is unavailable", function()
  local original_path = vim.env.PATH
  vim.env.PATH = root .. "/no-executables"
  eq(nil, utils.get_git_root(file))
  eq("Auto\nsaved", storage.get(file, 1).text)
  vim.env.PATH = original_path
end)

test("setup restores notes in an already loaded buffer", function()
  vim.api.nvim_buf_clear_namespace(0, setters.namespace(), 0, -1)
  eq(0, #vim.api.nvim_buf_get_extmarks(0, setters.namespace(), 0, -1, {}))
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
  eq(2, #vim.api.nvim_buf_get_extmarks(0, setters.namespace(), 0, -1, {}))
end)

test("reconfiguration updates the namespace, prefix and picker paths", function()
  local old_ns = setters.namespace()
  ghostnotes.setup({ keymaps = false, namespace = "ghostnotes-test-custom", note_prefix = "NOTE: ",
    path_format = ":p", picker = { provider = "select" } })
  eq(0, #vim.api.nvim_buf_get_extmarks(0, old_ns, 0, -1, {}))
  local marks = vim.api.nvim_buf_get_extmarks(0, setters.namespace(), 0, -1, { details = true })
  eq(2, #marks)
  assert(marks[1][4].virt_text[1][1]:find("NOTE: ", 1, true) == 1)
  local items = common.build_items({ storage.get(file, 1) }, require("ghostnotes.config").opts.path_format)
  eq(file, items[1].source_file)
  local custom_ns = setters.namespace()
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
  eq(0, #vim.api.nvim_buf_get_extmarks(0, custom_ns, 0, -1, {}))
end)

test("out-of-range notes are safe to restore and relocate", function()
  local note = { bufname = file, row = 20, text = "Out of range" }
  storage.upsert(note)
  vim.cmd("edit!")
  eq(2, #vim.api.nvim_buf_get_extmarks(0, setters.namespace(), 0, -1, {}))
  common.open_note({ bufname = file, row = 20, note_text = note.text })
  eq(4, vim.api.nvim_win_get_cursor(0)[1])
  assert(storage.get(file, 3))
  eq(nil, storage.get(file, 20))
end)

test("missing files are hidden, never recreated or removed from storage", function()
  local missing = project .. "/deleted.lua"
  vim.fn.writefile({ "line" }, missing)
  local note = { bufname = missing, row = 0, text = "Keep me" }
  storage.upsert(note)
  vim.fn.delete(missing)
  local all = utils.read_json(utils.get_global_path())
  local items, count = common.build_items(all, ":t", true)
  eq(1, count)
  for _, item in ipairs(items) do assert(item.bufname ~= missing) end
  common.open_note({ bufname = missing, row = 0, note_text = note.text })
  eq(0, vim.fn.filereadable(missing))
  assert(storage.get(missing, 0))
end)

test("fallback search matches the full body without displaying it", function()
  local text = "Short headline\n" .. string.rep("x", 250) .. " secretneedle"
  storage.upsert({ bufname = file, row = 0, text = text })
  local old_input, old_select = vim.ui.input, vim.ui.select
  local selected
  vim.ui.input = function(_, cb) cb("secretneedle") end
  vim.ui.select = function(items, opts, cb)
    eq(1, #items)
    assert(not opts.format_item(items[1]):find("secretneedle", 1, true))
    selected = items[1]
    cb(items[1])
  end
  require("ghostnotes.finder.grep_notes_global").grep_notes_global()
  vim.ui.input, vim.ui.select = old_input, old_select
  assert(selected)
  eq(1, vim.api.nvim_win_get_cursor(0)[1])
end)

test("selection in the current modified buffer does not reload it", function()
  local saved_hidden = vim.o.hidden
  vim.o.hidden = false
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "unsaved change" })
  common.open_note({ bufname = file, row = 1, note_text = "Auto\nsaved" })
  eq("unsaved change", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  assert(vim.bo.modified)
  eq(2, vim.api.nvim_win_get_cursor(0)[1])
  vim.cmd("edit!")
  vim.o.hidden = saved_hidden
end)

test("an out-of-range note is kept when all lines are occupied", function()
  local note = { bufname = file, row = 50, text = "No room" }
  storage.upsert(note)
  common.open_note({ bufname = file, row = 50, note_text = note.text })
  assert(storage.get(file, 50))
  eq(4, vim.api.nvim_win_get_cursor(0)[1])
  storage.delete(file, 50)
end)

test("invalid JSON is not silently overwritten", function()
  local global = utils.get_global_path()
  local saved = utils.read_json(global)
  local project_path = project .. "/.ghostnotes.json"
  local before = vim.fn.readfile(project_path)
  vim.fn.writefile({ "not json" }, global)
  local ok, err = pcall(storage.upsert, { bufname = file, row = 0, text = "must not overwrite" })
  assert(not ok and tostring(err):find("invalid note store", 1, true))
  eq({ "not json" }, vim.fn.readfile(global))
  eq(before, vim.fn.readfile(project_path))
  vim.fn.writefile({ "[123]" }, global)
  ok, err = pcall(storage.upsert, { bufname = file, row = 0, text = "must not overwrite" })
  assert(not ok and tostring(err):find("invalid note", 1, true))
  eq({ "[123]" }, vim.fn.readfile(global))
  eq(before, vim.fn.readfile(project_path))
  utils.write_json(global, saved)
end)

test("failed editor writes leave the note modified", function()
  local global = utils.get_global_path()
  local saved = utils.read_json(global)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("Ghostnotes edit")
  local float = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(float, 0, -1, false, { "must not be lost" })
  vim.fn.writefile({ "not json" }, global)
  local ok = pcall(vim.cmd, "write")
  assert(not ok and vim.bo[float].modified)
  eq({ "not json" }, vim.fn.readfile(global))
  utils.write_json(global, saved)
  vim.cmd("write")
  vim.cmd("close")
  eq("must not be lost", storage.get(file, 1).text)
end)

test("an unavailable explicit picker reports an error", function()
  local loaded = package.loaded["telescope.pickers"]
  local preload = package.preload["telescope.pickers"]
  package.loaded["telescope.pickers"] = nil
  package.preload["telescope.pickers"] = function() error("Telescope unavailable for this test") end
  ghostnotes.setup({ keymaps = false, picker = { provider = "telescope" } })
  eq(nil, require("ghostnotes.finder.grep_common").provider())
  assert(messages[#messages][1]:find("unavailable", 1, true))
  package.loaded["telescope.pickers"] = loaded
  package.preload["telescope.pickers"] = preload
  ghostnotes.setup({ keymaps = false, picker = { provider = "select" } })
end)

test("health check reports missing source files", function()
  local old_health = vim.health
  local results = {}
  vim.health = {}
  for _, key in ipairs({ "start", "ok", "info", "warn", "error" }) do
    vim.health[key] = function(message) results[#results + 1] = { key, message } end
  end
  require("ghostnotes.health").check()
  vim.health = old_health
  local found = false
  for _, item in ipairs(results) do
    if item[1] == "warn" and item[2]:find("missing files", 1, true) then found = true end
  end
  assert(found, vim.inspect(results))
end)
