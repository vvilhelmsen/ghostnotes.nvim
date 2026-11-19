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
      live = opts.search_body,
      finder = opts.search_body and function(_, ctx)
        local query = ctx.filter.search:lower()
        local matches = {}
        for _, item in ipairs(items) do
          if item.note_text:lower():find(query, 1, true) then
            matches[#matches + 1] = vim.tbl_extend("force", {}, item)
          end
        end
        return matches
      end or nil,
      format = common.format_ghostnote,
      preview = function(ctx)
        common.snacks_preview(ctx, opts.search_body and ctx.picker:filter().search or nil)
      end,
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
    local sorter = opts.search_body and require("telescope.sorters").new({
      scoring_function = function(_, prompt, _, entry)
        return entry.value.note_text:lower():find(vim.trim(prompt):lower(), 1, true) and 1 or -1
      end,
    }) or require("telescope.config").values.generic_sorter({})
    require("telescope.pickers").new({}, {
      prompt_title = opts.title,
      finder = require("telescope.finders").new_table({
        results = items,
        entry_maker = function(item)
          return { value = item, display = make_display, ordinal = item.text }
        end,
      }),
      sorter = sorter,
      previewer = common.tel_previewer(opts.search_body),
      on_complete = opts.search_body and { function(picker)
        vim.schedule(function()
          local state = picker.previewer and picker.previewer.state
          if picker:get_selection() and state and state.bufnr and state.winid and vim.api.nvim_buf_is_valid(state.bufnr)
            and vim.api.nvim_win_is_valid(state.winid) and vim.api.nvim_win_get_buf(state.winid) == state.bufnr then
            common.highlight_preview(state.bufnr, state.winid, action_state.get_current_line())
          end
        end)
      end } or nil,
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
      query = vim.trim(query):lower()
      local matching = vim.tbl_filter(function(item)
        return (opts.search_body and item.note_text or item.text):lower():find(query, 1, true) ~= nil
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
