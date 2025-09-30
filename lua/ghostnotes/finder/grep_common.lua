local config      = require("ghostnotes.config").opts
local build_items = require("ghostnotes.finder.common").build_items

local M = {}

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
        local normalized = vim.tbl_extend("force", {}, item, {
          row = math.max((item.row or 1) - 1, 0),
        })
        on_confirm(normalized)
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
        -- items.row 1-based for display
        ctx.preview:set_title(string.format("%s (line %d)", name, (ctx.item.row or 1)))
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

    local make_display = require("ghostnotes.finder.common").tel_create_displayer(items)
    local prev = require("ghostnotes.finder.common").tel_previewer()

    pickers.new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = items,
        entry_maker = function(it)
          return {
            value   = it,
            display = make_display,
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
