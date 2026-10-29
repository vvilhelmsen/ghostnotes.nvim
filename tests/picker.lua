local provider = vim.env.GHOSTNOTES_TEST_PICKER
vim.o.columns = 160
vim.o.lines = 50
if provider == "snacks" then
  vim.opt.runtimepath:append(vim.env.SNACKS_DIR)
  require("snacks").setup({ picker = { enabled = true } })
else
  vim.opt.runtimepath:append(vim.env.PLENARY_DIR)
  vim.opt.runtimepath:append(vim.env.TELESCOPE_DIR)
  require("telescope").setup({})
end

local root = vim.env.GHOSTNOTES_TEST_WORK .. "/picker-" .. provider
vim.fn.mkdir(root, "p")
vim.fn.system({ "git", "init", "-q", root })
assert(vim.v.shell_error == 0)
local alpha = root .. "/alpha file.lua"
local beta = root .. "/beta.lua"
vim.fn.writefile({ "first", "second", "third" }, alpha)
vim.fn.writefile({ "one", "two" }, beta)
vim.cmd("cd " .. vim.fn.fnameescape(root))
vim.cmd("edit " .. vim.fn.fnameescape(beta))

local ghostnotes = require("ghostnotes")
ghostnotes.setup({ keymaps = false, picker = { provider = "auto" } })
assert(require("ghostnotes.finder.grep_common").provider() == provider, "auto did not select " .. provider)
ghostnotes.setup({ keymaps = false, picker = { provider = provider } })
local utils = require("ghostnotes.utils")
local storage = require("ghostnotes.storage")
utils.write_json(utils.get_global_path(), {})
local body = string.rep("x", 250) .. " uniquebodyneedle"
storage.upsert({ bufname = alpha, row = 1, text = "Alpha headline\n" .. body .. "\n" })
storage.upsert({ bufname = beta, row = 0, text = "Beta headline\nOther body" })

local function wait_for(fn, what)
  assert(vim.wait(5000, fn, 10), "timed out waiting for " .. what)
end

local function eq(expected, actual)
  assert(vim.deep_equal(expected, actual), ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
end

local function open_picker(command)
  vim.cmd("edit " .. vim.fn.fnameescape(beta))
  vim.cmd("Ghostnotes " .. command)
  if provider == "snacks" then
    local picker
    wait_for(function()
      picker = require("snacks").picker.get()[1]
      return picker and picker.list:count() == 2
    end, "Snacks results for " .. command)
    return picker
  end
  local prompt = vim.api.nvim_get_current_buf()
  local picker = require("telescope.actions.state").get_current_picker(prompt)
  assert(picker, "Telescope did not open")
  wait_for(function() return picker.manager and picker.manager:num_results() == 2 end, "Telescope results for " .. command)
  return picker
end

local function search(picker, query)
  if provider == "snacks" then
    picker.input:set(query)
    picker:find({ refresh = false })
    wait_for(function() return picker.list:count() == 1 and picker:current() ~= nil end, "Snacks filtered result")
    eq(alpha, picker:current().bufname)
    picker:show_preview()
    wait_for(function()
      return picker.preview.win.buf and vim.api.nvim_buf_is_valid(picker.preview.win.buf)
        and vim.api.nvim_buf_get_lines(picker.preview.win.buf, 0, 1, false)[1] == "Alpha headline"
    end, "Snacks preview")
    eq({ "Alpha headline", body, "" }, vim.api.nvim_buf_get_lines(picker.preview.win.buf, 0, -1, false))
    local rendered = table.concat(vim.api.nvim_buf_get_lines(picker.list.win.buf, 0, -1, false), "\n")
    assert(not rendered:find("uniquebodyneedle", 1, true), rendered)
    picker:action("confirm")
  else
    picker:reset_prompt(query)
    wait_for(function()
      return picker.manager and picker.manager:num_results() == 1
        and require("telescope.actions.state").get_selected_entry() ~= nil
    end, "Telescope filtered result")
    eq(alpha, require("telescope.actions.state").get_selected_entry().value.bufname)
    wait_for(function()
      local buf = picker.previewer.state and picker.previewer.state.bufnr
      return buf and vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "Alpha headline"
    end, "Telescope preview")
    eq({ "Alpha headline", body, "" }, vim.api.nvim_buf_get_lines(picker.previewer.state.bufnr, 0, -1, false))
    eq("markdown", vim.bo[picker.previewer.state.bufnr].filetype)
    local rendered = table.concat(vim.api.nvim_buf_get_lines(picker.results_bufnr, 0, -1, false), "\n")
    assert(not rendered:find("uniquebodyneedle", 1, true), rendered)
    require("telescope.actions").select_default(picker.prompt_bufnr)
  end
  wait_for(function() return vim.api.nvim_buf_get_name(0) == alpha end, "opening selected file")
  eq(2, vim.api.nvim_win_get_cursor(0)[1])
  local marks = vim.api.nvim_buf_get_extmarks(0, require("ghostnotes.note_operations.setters").namespace(), 0, -1, {})
  eq(1, #marks)
  eq(1, marks[1][2])
end

for _, case in ipairs({
  { "find", "alpha" },
  { "find_project", "alpha" },
  { "grep", "uniquebodyneedle" },
  { "grep_project", "uniquebodyneedle" },
}) do
  local picker = open_picker(case[1])
  search(picker, case[2])
  print("PASS " .. provider .. " " .. case[1] .. " filtering, preview and selection")
end

do
  local picker = open_picker("find")
  if provider == "snacks" then
    picker.input:set("uniquebodyneedle")
    picker:find({ refresh = false })
    wait_for(function() return picker.list:count() == 0 end, "Snacks find-only filtering")
    picker:close()
  else
    picker:reset_prompt("uniquebodyneedle")
    wait_for(function() return picker.manager and picker.manager:num_results() == 0 end, "Telescope find-only filtering")
    require("telescope.actions").close(picker.prompt_bufnr)
  end
  print("PASS " .. provider .. " find ignores note bodies")
end

if provider == "telescope" then
  local picker = open_picker("grep")
  picker:reset_prompt("nomatchingghostnote")
  wait_for(function() return picker.manager and picker.manager:num_results() == 0 end, "empty Telescope results")
  require("telescope.actions").select_default(picker.prompt_bufnr)
  print("PASS telescope empty selection")
end

do
  local victim = root .. "/deleted-after-open.lua"
  vim.fn.writefile({ "victim" }, victim)
  storage.upsert({ bufname = victim, row = 0, text = "Victim\nvanishingneedle" })
  vim.cmd("edit " .. vim.fn.fnameescape(beta))
  vim.cmd("Ghostnotes grep")
  if provider == "snacks" then
    local picker
    wait_for(function()
      picker = require("snacks").picker.get()[1]
      return picker and picker.list:count() == 3
    end, "Snacks results before deletion")
    picker.input:set("vanishingneedle")
    picker:find({ refresh = false })
    wait_for(function() return picker.list:count() == 1 and picker:current() ~= nil end, "Snacks deleted-file result")
    vim.fn.delete(victim)
    picker:action("confirm")
  else
    local prompt = vim.api.nvim_get_current_buf()
    local picker = require("telescope.actions.state").get_current_picker(prompt)
    wait_for(function() return picker.manager and picker.manager:num_results() == 3 end, "Telescope results before deletion")
    picker:reset_prompt("vanishingneedle")
    wait_for(function()
      return picker.manager and picker.manager:num_results() == 1
        and require("telescope.actions.state").get_selected_entry() ~= nil
    end, "Telescope deleted-file result")
    vim.fn.delete(victim)
    require("telescope.actions").select_default(prompt)
  end
  wait_for(function() return vim.api.nvim_buf_get_name(0) == beta end, "returning after missing file")
  assert(vim.fn.filereadable(victim) == 0, "picker recreated deleted file")
  assert(storage.get(victim, 0), "picker deleted the note")
  print("PASS " .. provider .. " source deleted while picker is open")
end

assert(vim.fn.isdirectory(vim.fn.stdpath("data") .. "/ghostnotes/previews") == 0,
  "picker must not write note previews to disk")
