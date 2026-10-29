---@class GhostnotesKeymaps
---@field clear_line? string|false
---@field find_global? string|false
---@field find_local? string|false
---@field yank_line? string|false
---@field paste_note? string|false
---@field edit_or_view_note? string|false
---@field grep_global? string|false
---@field grep_local? string|false

---@class GhostnotesConfig
---@field keymaps GhostnotesKeymaps|false
---@field autowrite boolean
---@field namespace string
---@field note_prefix string
---@field path_format string
---@field picker GhostnotesPickerConfig

---@class GhostnotesPickerConfig
---@field provider "auto"|"snacks"|"telescope"|"select"
---@field highlighting {file: string, row: string, head: string}
---@field boundaries {file: {min: integer, max: integer}, row: {min: integer, max: integer?}}
---@field separator string

---@class GhostnotesSetupOptions
---@field keymaps? GhostnotesKeymaps|false
---@field autowrite? boolean
---@field namespace? string
---@field note_prefix? string
---@field path_format? string
---@field picker? {provider?: "auto"|"snacks"|"telescope"|"select", highlighting?: table, boundaries?: table, separator?: string}

---@type GhostnotesConfig
local defaults = {
  keymaps = {
    clear_line = "<leader>gnc",
    find_global = "<leader>gnf",
    find_local = "<leader>gnF",
    yank_line = "<leader>gny",
    paste_note = "<leader>gnp",
    edit_or_view_note = "<leader>gne",
    grep_global = "<leader>gng",
    grep_local = "<leader>gnG",
  },
  autowrite = true,
  namespace = "ghostnotes",
  note_prefix = "👻 ",
  path_format = ":t",
  picker = {
    provider = "auto",
    highlighting = { file = "Normal", row = "LineNr", head = "String" },
    boundaries = { file = { min = 5, max = 25 }, row = { min = 0 } },
    separator = " ",
  },
}

---@class GhostnotesConfigModule
---@field opts GhostnotesConfig
local M = { opts = vim.deepcopy(defaults) }

---@param user_opts? GhostnotesSetupOptions
function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_opts or {})
  local provider = M.opts.picker.provider
  assert(provider == "auto" or provider == "snacks" or provider == "telescope" or provider == "select",
    "ghostnotes: picker.provider must be auto, snacks, telescope, or select")
end

return M
