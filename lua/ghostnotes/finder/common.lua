local config        = require("ghostnotes.config").opts
local get_head      = require("ghostnotes.note_operations.getters").get_note_headline
local utils         = require("ghostnotes.utils")

local M             = {}

local hl            = config.picker.highlighting
local bo            = config.picker.boundaries

local function oneline(s)
  s = (s or ""):gsub("%s+", " ")
  if #s > 200 then s = s:sub(1, 200) .. "…" end
  return s
end

M.format_ghostnote = function(item, picker)
  return {
    { item.source_file, "Directory" },
    { ":", "Comment" },
    { tostring(item.row), "LineNr" },
    { " → ", "Comment" },
    { item.head, "Normal" },
  }
end

M.build_items = function(notes, path_format)
  local out = {}
  for _, n in ipairs(notes or {}) do
    local source_file = vim.fn.fnamemodify(n.bufname, path_format)
    local head = get_head(n)
    local row = (n.row or 0) + 1
    local display = source_file .. ":" .. row .. " → " .. head
    local body = oneline(n.text)
    
    -- Create preview markdown file for Snacks to render
    local preview_file = utils.create_preview_file(n)
    
    table.insert(out, {
      bufname     = n.bufname,
      row         = row,
      note_text   = n.text,
      head        = head,
      timestamp   = n.timestamp,
      source_file = source_file,  -- Keep original file for display
      -- right now grepping only works if we display the body. Looks ugly but works
      text        = body ~= "" and (display .. " — " .. body) or display,
      file        = preview_file,  -- Point to preview markdown file for Snacks
      display     = display,
    })
  end
  return out
end

M.tel_create_displayer = function(items)
  local entry_display = require "telescope.pickers.entry_display"
  local function calc_field_length(name, entries, min, max)
    local length = min or 0
    for _, entry in pairs(entries) do
      local field = tostring(entry[name])
      if field and #field > length then
        length = #field
        if max and length >= max then return end
      end
    end
    return length
  end

  local displayer = entry_display.create({
    separator = config.picker.separator,
    items = {
      { width = calc_field_length("source_file", items, bo.file.min, bo.file.min) },
      { width = calc_field_length("row", items, bo.row.min, bo.row.max) },
      { remaining = true }
    }
  })

  local function make_display(entry)
    local val = entry.value
    return displayer {
      { val.source_file, hl.file },
      { val.row,  hl.row },
      { val.head, hl.head },
    }
  end

  return make_display
end

-- Custom Snacks preview function that reads the preview .md file
-- and applies treesitter markdown highlighting without triggering render-markdown
M.snacks_preview = function(ctx)
  local item = ctx.item
  if not item or not item.file then
    ctx.preview:notify("No preview available", "warn")
    return
  end

  local path = item.file
  local file = io.open(path, "r")
  if not file then
    ctx.preview:notify("Preview file not found", "warn")
    return
  end

  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  if #lines == 0 then
    lines = { "(Empty note)" }
  end

  ctx.preview:reset()
  ctx.preview:set_lines(lines)
  pcall(vim.treesitter.start, ctx.buf, "markdown")
end

M.tel_previewer = function()
  local previewers = require("telescope.previewers")

  return previewers.new_buffer_previewer({
    title = "Note Preview",
    define_preview = function(self, entry, _)
      local note = entry.value
      local lines = {}
      for line in (note.note_text or ""):gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
      end
      if #lines == 0 then lines = { "(Empty note)" } end
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_set_option_value("filetype", "markdown", { scope = "local", buf = self.state.bufnr })
    end,
  })
end

return M
