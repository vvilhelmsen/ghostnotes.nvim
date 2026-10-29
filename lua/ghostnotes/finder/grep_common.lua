local config = require("ghostnotes.config")
local common = require("ghostnotes.finder.common")
local M = {}

---Resolve the configured picker. Explicitly requested missing providers are reported.
---@return "snacks"|"telescope"|"select"|nil
function M.provider()
  local requested = config.opts.picker.provider
  if requested == "select" then return "select" end
  if requested == "auto" or requested == "snacks" then
    local ok, snacks = pcall(require, "snacks")
    local picker_ok, picker = pcall(function() return ok and snacks.picker end)
    if picker_ok and picker and type(picker.pick) == "function"
      and (requested == "snacks" or not (snacks.config and snacks.config.picker.enabled == false)) then
      return "snacks"
    end
  end
  if requested == "auto" or requested == "telescope" then
    local ok = pcall(require, "telescope.pickers")
    if ok then return "telescope" end
  end
  if requested ~= "auto" then
    vim.notify("Ghostnotes picker provider is unavailable: " .. requested, vim.log.levels.ERROR)
    return nil
  end
  return "select"
end

---@class GhostnotesPickerOptions
---@field title string
---@field notes GhostnotesNote[]
---@field search_body? boolean
---@field on_confirm? fun(item: GhostnotesPickerItem)

---@param opts GhostnotesPickerOptions
function M.open_picker(opts)
  local items, missing = common.build_items(opts.notes, config.opts.path_format, opts.search_body)
  if missing > 0 then
    vim.notify(("Skipped %d ghost note(s) whose source files are missing. Notes remain in storage."):format(missing), vim.log.levels.WARN)
  end
  if #items == 0 then
    vim.notify("No available ghost notes to search", vim.log.levels.INFO)
    return
  end
  local on_confirm = opts.on_confirm or common.open_note
  local provider = M.provider()
  if provider == "snacks" then
    require("snacks").picker.pick({
      title = opts.title,
      prompt = "> ",
      items = items,
      format = common.format_ghostnote,
      preview = common.snacks_preview,
      confirm = function(picker, item)
        if not item then return end
        picker:close()
        on_confirm(item)
      end,
    })
  elseif provider == "telescope" then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local make_display = common.tel_create_displayer(items)
    require("telescope.pickers").new({}, {
      prompt_title = opts.title,
      finder = require("telescope.finders").new_table({
        results = items,
        entry_maker = function(item)
          return { value = item, display = make_display, ordinal = item.text }
        end,
      }),
      sorter = require("telescope.config").values.generic_sorter({}),
      previewer = common.tel_previewer(),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selected = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selected and selected.value then on_confirm(selected.value) end
        end)
        return true
      end,
    }):find()
  elseif provider == "select" then
    local function select_matching(query)
      if query == nil then return end
      local matching = vim.tbl_filter(function(item)
        return item.text:lower():find(query:lower(), 1, true) ~= nil
      end, items)
      if #matching == 0 then
        vim.notify("No matching ghost notes", vim.log.levels.INFO)
        return
      end
      vim.ui.select(matching, { prompt = opts.title, format_item = function(item) return item.display end }, on_confirm)
    end
    if opts.search_body then
      vim.ui.input({ prompt = "Search ghost notes: " }, select_matching)
    else
      select_matching("")
    end
  end
end

return M
