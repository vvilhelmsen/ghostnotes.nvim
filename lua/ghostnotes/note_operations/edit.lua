local config = require("ghostnotes.config")
local storage = require("ghostnotes.storage")
local setters = require("ghostnotes.note_operations.setters")
local M = {}

---Open the note editor for the current file and line.
function M.edit_or_view_note()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" or vim.bo[bufnr].buftype ~= "" then
    vim.notify("Ghost notes require a named file buffer", vim.log.levels.WARN)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local note = storage.get(bufname, row)
  local lines = note and vim.split(note.text, "\n", { plain = true }) or { "" }

  local float_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
  vim.bo[float_buf].bufhidden = "wipe"
  vim.bo[float_buf].filetype = "markdown"
  vim.bo[float_buf].buftype = "acwrite"
  vim.bo[float_buf].swapfile = false
  vim.api.nvim_buf_set_name(float_buf, ("ghostnote://%d/%d/%d"):format(float_buf, bufnr, row + 1))
  vim.bo[float_buf].modified = false

  local width = math.max(1, math.floor(vim.o.columns * 0.5))
  local height = math.max(1, math.min(vim.o.lines - 2, math.max(math.floor(vim.o.lines * 0.75), #lines + 2)))
  local title = config.opts.autowrite and " q: save/exit ┃ L1: headline ┃ L2+: body "
    or " :w/:q save/exit ┃ L1: headline ┃ L2+: body "
  local win = vim.api.nvim_open_win(float_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  vim.wo[win].wrap = true

  local function save_note()
    local text = table.concat(vim.api.nvim_buf_get_lines(float_buf, 0, -1, false), "\n")
    if text:match("^%s*$") then
      if note then
        storage.delete(bufname, row)
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_clear_namespace(bufnr, setters.namespace(), row, row + 1)
        end
        note = nil
        vim.notify("Deleted ghost note", vim.log.levels.INFO)
      end
    else
      local new_note = {
        bufname = bufname,
        row = row,
        text = text,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }
      storage.upsert(new_note)
      if vim.api.nvim_buf_is_valid(bufnr) then setters.mark_note(bufnr, new_note) end
      vim.notify(note and "Saved ghost note" or "Added ghost note", vim.log.levels.INFO)
      note = new_note
    end
    vim.bo[float_buf].modified = false
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = float_buf,
    callback = save_note,
    desc = "Save ghost note",
  })

  if config.opts.autowrite then
    vim.keymap.set("n", "q", function()
      if vim.bo[float_buf].modified then vim.cmd("write") end
      vim.cmd("close")
    end, { buffer = float_buf, silent = true, desc = "Save and close ghost note" })
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = float_buf,
      callback = function()
        if vim.bo[float_buf].modified then save_note() end
      end,
      desc = "Save ghost note on leave",
    })
  end
  vim.cmd("stopinsert")
end

return M
