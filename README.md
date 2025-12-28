# 👻 ghostnotes.nvim

Add simple, persistent virtual notes to any line in your code. Markdown supported.

(Snacks or Telescope is needed for preview to work)

Want something added or changed? **Create an issue!**

**Contributions are welcome :)**

---
## Table of Contents

- [Example](#example)
- [Install](#install)
- [Configuration](#configuration)
- [Default Keymaps](#default-keymaps)

---

## Example

### Adding a note
Notes are added either as a simple inline virtual comment (if no body is supplied), or with a full body, like in the picture below:

<img width="1162" height="967" alt="image" src="https://github.com/user-attachments/assets/732aef70-3b92-493f-8871-e7380792f31b" />

### Finding notes

Ghost notes you have made can be found by using `leader + gnf` to find ALL your ghost notes, or `leader + gnF` to find ghost notes in your current project. You can also grep for content inside notes by doing `leader + gng` or `leader + gnG`.

<img width="1163" height="957" alt="image" src="https://github.com/user-attachments/assets/7126a2fc-4648-4d20-90f9-622d55f82ccb" />

If neither telescope nor snacks is installed you will get a simple picker that lets you see the headline and also moves you to the location of the note when picked. Grepping will not work without telescope / snacks.

---
## Install

lazy.nvim:

```lua
{
  "vvilhelmsen/ghostnotes.nvim",
  -- Optional overrides
  opts = {}
}
```

---

## Configuration

You can configure ghostnotes by passing options to the `setup` function or via `opts` in lazy.nvim.

```lua
opts = {
  -- If true, pressing `q` in the note window will save and close (if modified),
  -- or just close (if not modified).
  -- If false, you must use `:w`, `:wq`, or `ZZ` to save.
  autowrite = true,

  keymaps = {
    clear_line        = "<leader>gnc", -- Clears note and yanks it to register "g"
    find_global       = "<leader>gnf",
    find_local        = "<leader>gnF",
    yank_line         = "<leader>gny", -- Yanks note to register "g"
    paste_note        = "<leader>gnp", -- Creates a note from register "g"
    edit_or_view_note = "<leader>gne",
    grep_global       = "<leader>gng",
    grep_local        = "<leader>gnG",
  },
  
  note_prefix = "👻 ",
  
  -- Controls how file paths are displayed in pickers
  -- :t = tail (filename only), :~ = relative to home, etc.
  path_format = ":t",
}
```

---

## Default Keymaps

| Option name         | Default       | Description |
| ------------------- | ------------- | ----------- |
| `edit_or_view_note` | `<leader>gne` | Open note editor for current line |
| `clear_line`        | `<leader>gnc` | Delete note on current line (also yanks to "g") |
| `find_global`       | `<leader>gnf` | Find notes in all known files |
| `find_local`        | `<leader>gnF` | Find notes in current git project |
| `grep_global`       | `<leader>gng` | Live grep inside all notes |
| `grep_local`        | `<leader>gnG` | Live grep inside project notes |
| `yank_line`         | `<leader>gny` | Yank current note text to register "g" |
| `paste_note`        | `<leader>gnp` | Create note from register "g" contents |

---

MIT License
