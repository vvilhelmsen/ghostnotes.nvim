local M = {}

---Report picker availability and note storage problems for :checkhealth.
function M.check()
  local health = vim.health
  local utils = require("ghostnotes.utils")
  local config = require("ghostnotes.config").opts
  health.start("ghostnotes.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim 0.10 or newer")
  else
    health.error("Neovim 0.10 or newer is required")
  end
  if vim.fn.executable("git") == 1 then
    health.ok("Git is available for project notes")
  else
    health.warn("Git is not available; project notes are disabled")
  end

  local snacks_ok, snacks = pcall(require, "snacks")
  local snacks_picker_ok, snacks_picker = pcall(function() return snacks_ok and snacks.picker end)
  local snacks_available = snacks_picker_ok and snacks_picker and type(snacks_picker.pick) == "function"
  local snacks_auto = snacks_available and not (snacks.config and snacks.config.picker.enabled == false)
  local telescope_available = pcall(require, "telescope.pickers")
  if snacks_available and not snacks_auto then
    health.info("Snacks picker is available but disabled in Snacks configuration")
  elseif snacks_available then
    health.ok("Snacks picker is available")
  else
    health.info("Snacks picker is not available")
  end
  if telescope_available then
    health.ok("Telescope is available")
  else
    health.info("Telescope is not available")
  end
  local requested = config.picker.provider
  if (requested == "snacks" and not snacks_available) or (requested == "telescope" and not telescope_available) then
    health.error("Configured picker is unavailable: " .. requested)
  elseif requested == "auto" and not snacks_auto and not telescope_available then
    health.info("Using vim.ui.select and vim.ui.input as a fallback")
  else
    health.ok("Picker provider: " .. requested)
  end

  local ok, path = pcall(utils.get_global_path)
  if not ok then
    health.error(tostring(path))
    return
  end
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.filewritable(dir) ~= 2 then
    health.error("Global note directory is not writable: " .. dir)
  elseif vim.fn.filereadable(path) == 1 and vim.fn.filewritable(path) ~= 1 then
    health.warn("Global note file is not writable: " .. path)
  else
    health.ok("Global note directory is writable: " .. dir)
  end
  local read_ok, notes = pcall(utils.read_json, path)
  if not read_ok then
    health.error(tostring(notes))
    return
  end
  local missing = 0
  for _, note in ipairs(notes) do
    if type(note) == "table" and not utils.source_exists(note) then missing = missing + 1 end
  end
  if missing > 0 then
    health.warn(("%d note(s) refer to missing files. They remain in %s and are hidden from pickers."):format(missing, path))
  else
    health.ok("Global note store is readable")
  end

  local root = utils.get_git_root()
  if root then
    local project_path = root .. "/.ghostnotes.json"
    if vim.fn.filewritable(root) ~= 2 then
      health.warn("Project note directory is not writable: " .. root)
    elseif vim.fn.filereadable(project_path) == 1 and vim.fn.filewritable(project_path) ~= 1 then
      health.warn("Project note file is not writable: " .. project_path)
    else
      health.ok("Project note directory is writable: " .. root)
    end
    local project_ok, err = pcall(utils.read_json, project_path)
    if not project_ok then health.error(tostring(err)) end
  end
end

return M
