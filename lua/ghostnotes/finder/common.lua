local config = require("ghostnotes.config")
local get_headline = require("ghostnotes.note_operations.getters").get_note_headline
local storage = require("ghostnotes.storage")
local setters = require("ghostnotes.note_operations.setters")
local utils = require("ghostnotes.utils")
local M = {}
local preview_ns = vim.api.nvim_create_namespace("ghostnotes.preview")

---@class GhostnotesPickerItem
---@field bufname string
---@field row integer Zero-based source line
---@field lnum integer One-based source line for display
---@field note_text string
---@field source_file string
---@field head string
---@field display string
---@field text string Searchable text, which may include the note body
---@field timestamp? string

---Build picker entries without writing note contents to preview files.
---@param notes GhostnotesNote[]
---@param path_format string
---@param search_body? boolean
---@return GhostnotesPickerItem[], integer missing
function M.build_items(notes, path_format, search_body)
  local items, missing = {}, 0
  for _, note in ipairs(notes or {}) do
    if type(note) == "table" and type(note.row) == "number" and note.row >= 0 and note.row % 1 == 0
      and type(note.text) == "string" and type(note.bufname) == "string" then
      if utils.source_exists(note) then
        local source_file = vim.fn.fnamemodify(note.bufname, path_format)
        local head = get_headline(note)
        local display = ("%s:%d → %s"):format(source_file, note.row + 1, head)
        local text = search_body and note.text:gsub("%s+", " ") or display
        items[#items + 1] = {
          bufname = note.bufname,
          row = note.row,
          lnum = note.row + 1,
          note_text = note.text,
          timestamp = note.timestamp,
          source_file = source_file,
          head = head,
          display = display,
          text = text,
        }
      else
        missing = missing + 1
      end
    end
  end
  return items, missing
end

---@param item GhostnotesPickerItem
---@return table[]
function M.format_ghostnote(item)
  local hl = config.opts.picker.highlighting
  return {
    { item.source_file, hl.file },
    { ":", "Comment" },
    { tostring(item.lnum), hl.row },
    { " → ", "Comment" },
    { item.head, hl.head },
  }
end

---@param items GhostnotesPickerItem[]
---@return fun(entry: table): string, table
function M.tel_create_displayer(items)
  local entry_display = require("telescope.pickers.entry_display")
  local opts = config.opts.picker
  local function width(field, bounds)
    local result = bounds.min or 0
    for _, item in ipairs(items) do
      result = math.max(result, vim.fn.strdisplaywidth(tostring(item[field])))
    end
    return bounds.max and math.min(result, bounds.max) or result
  end
  local displayer = entry_display.create({
    separator = opts.separator,
    items = {
      { width = width("source_file", opts.boundaries.file) },
      { width = width("lnum", opts.boundaries.row) },
      { remaining = true },
    },
  })
  return function(entry)
    local item = entry.value
    return displayer({
      { item.source_file, opts.highlighting.file },
      { tostring(item.lnum), opts.highlighting.row },
      { item.head, opts.highlighting.head },
    })
  end
end

---@param buf integer
---@param win integer
---@param query? string
function M.highlight_preview(buf, win, query)
  vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
  query = query and vim.trim(query) or ""
  if query == "" then return end
  local first
  local needle = query:lower()
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local start = 1
    local lower = line:lower()
    while true do
      local from, to = lower:find(needle, start, true)
      if not from then break end
      vim.api.nvim_buf_set_extmark(buf, preview_ns, row - 1, from - 1, {
        end_col = to,
        hl_group = "Search",
        priority = 200,
      })
      first = first or { row, from - 1 }
      start = from + 1
    end
  end
  if first and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, first)
    vim.api.nvim_win_call(win, function() vim.cmd("normal! zz") end)
  end
end

---@param ctx table Snacks preview context
---@param query? string
function M.snacks_preview(ctx, query)
  ctx.preview:reset()
  local text = ctx.item and ctx.item.note_text or ""
  local lines = text ~= "" and vim.split(text, "\n", { plain = true }) or { "(Empty note)" }
  ctx.preview:set_lines(lines)
  -- Keep the scratch buffer's filetype so render-markdown does not attach to it.
  if not pcall(vim.treesitter.start, ctx.buf, "markdown") then
    vim.bo[ctx.buf].syntax = "markdown"
  end
  M.highlight_preview(ctx.buf, ctx.win, query)
end

---@param search_body? boolean
---@return table
function M.tel_previewer(search_body)
  return require("telescope.previewers").new_buffer_previewer({
    title = "Note preview",
    define_preview = function(self, entry)
      local text = entry.value.note_text or ""
      local lines = text ~= "" and vim.split(text, "\n", { plain = true }) or { "(Empty note)" }
      local buf, win = self.state.bufnr, self.state.winid
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].filetype = "markdown"
      if search_body then
        local query = require("telescope.actions.state").get_current_line()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            M.highlight_preview(buf, win, query)
          end
        end)
      end
    end,
  })
end

---Open a picker result, relocating an out-of-range note only when a free line exists.
---@param item GhostnotesPickerItem?
function M.open_note(item)
  if not item then return end
  if not utils.source_exists(item) then
    vim.notify("Ghost note source no longer exists: " .. item.bufname, vim.log.levels.WARN)
    return
  end
  local bufnr = vim.fn.bufnr(item.bufname, false)
  local ok, err = pcall(function()
    if bufnr ~= -1 then
      vim.cmd("buffer " .. bufnr)
    else
      vim.cmd("edit " .. vim.fn.fnameescape(item.bufname))
    end
  end)
  if not ok then
    vim.notify("Cannot open ghost note source: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  bufnr = vim.api.nvim_get_current_buf()
  local row = item.row
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row >= line_count then
    local used = {}
    for _, note in ipairs(storage.for_buffer(item.bufname)) do used[note.row] = true end
    local new_row
    for candidate = line_count - 1, 0, -1 do
      if not used[candidate] then new_row = candidate; break end
    end
    if new_row then
      storage.move({ bufname = item.bufname, row = row, text = item.note_text }, new_row)
      vim.notify(("Line %d no longer exists; moved ghost note to line %d"):format(row + 1, new_row + 1), vim.log.levels.INFO)
      row = new_row
    else
      vim.notify("Ghost note is past the end of the file and no line is free; note was kept in storage", vim.log.levels.WARN)
      row = line_count - 1
    end
  end
  setters.apply_notes_for_buffer(bufnr)
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
end

return M
