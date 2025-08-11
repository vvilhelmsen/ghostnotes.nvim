local config   = require("ghostnotes.config")
local get_head = require("ghostnotes.note_operations.getters").get_note_headline

local M = {}

local function oneline(s)
  s = (s or ""):gsub("%s+", " ")
  if #s > 200 then s = s:sub(1, 200) .. "…" end
  return s
end

local function build_items(notes, path_format)
  local out = {}
  for _, n in ipairs(notes or {}) do
    local display = vim.fn.fnamemodify(n.bufname, path_format)
      .. ":" .. ((n.row or 0) + 1)
      .. " → " .. get_head(n)
    local body = oneline(n.text)
    table.insert(out, {
      bufname   = n.bufname,
      row       = n.row,
      note_text = n.text,
      timestamp = n.timestamp,
      -- right now grepping only works if we display the body. Looks ugly but works
      text      = body ~= "" and (display .. " — " .. body) or display,
      file      = n.bufname,
    })
  end
  return out
end

function M.open_picker(opts)
  local title       = opts.title
  local notes       = opts.notes or {}
  local path_format = opts.path_format or ":t"
  local on_confirm  = opts.on_confirm or function(_) end

  local items = build_items(notes, path_format)
  if vim.tbl_isempty(items) then
    vim.notify("No ghost notes to search", vim.log.levels.INFO)
    return
  end

  if Snacks and Snacks.picker then
    Snacks.picker.pick({
      title = title,
      prompt = "> ",
      items = items,
      format = "text",
      confirm = function(picker, item)
        if not item then return end
        picker:close()
        on_confirm(item)
      end,
      preview = function(ctx)
        ctx.preview:reset()
        local lines = {}
        if ctx.item.note_text then
          for line in ctx.item.note_text:gmatch("([^\n]*)\n?") do
            table.insert(lines, line)
          end
        end
        if #lines == 0 then lines = { "(Empty note)" } end
        ctx.preview:set_lines(lines)
        local name = vim.fn.fnamemodify(ctx.item.bufname, ":t")
        ctx.preview:set_title(string.format("%s (line %d)", name, (ctx.item.row or 0) + 1))
        ctx.preview:highlight({ ft = "markdown" })
      end,
    })
    return
  end

  local ok_t, telescope = pcall(require, "telescope")
  if ok_t then
    local pickers    = require("telescope.pickers")
    local finders    = require("telescope.finders")
    local conf       = require("telescope.config").values
    local actions    = require("telescope.actions")
    local action_st  = require("telescope.actions.state")
    local previewers = require("telescope.previewers")

    local prev = previewers.new_buffer_previewer({
      title = "Note Preview",
      define_preview = function(self, entry, _)
        local note = entry.value
        local lines = {}
        for line in (note.note_text or ""):gmatch("([^\n]*)\n?") do
          table.insert(lines, line)
        end
        if #lines == 0 then lines = { "(Empty note)" } end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      end,
    })

    pickers.new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = items,
        entry_maker = function(it)
          return {
            value   = it,
            display = it.text,
            ordinal = (it.text or "") .. "\n" .. (it.note_text or ""),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = prev,
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local sel = action_st.get_selected_entry()
          actions.close(prompt_bufnr)
          if sel and sel.value then on_confirm(sel.value) end
        end)
        return true
      end,
    }):find()
    return
  end

  -- Last resort fallback
  vim.ui.select(items, {
    prompt = title,
    format_item = function(it) return it.text end,
  }, function(choice) if choice then on_confirm(choice) end end)
end

return M
