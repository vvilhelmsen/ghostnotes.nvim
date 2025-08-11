# 👻 ghostnotes.nvim

Add simple, persistent virtual notes to any line in your code. Markdown supported.

(Snacks or Telescope is needed for preview to work)

**Contributions are welcome!**

---
## Table of Contents

- [Example](#example)
- [Install](#install)
- [Default Keymaps](#default-keymaps)

---

## Example

### Adding a note
Notes are added either as a simple inline virtual comment (if no body is supplied), or with a full body, like in the picture below:

<img width="1162" height="967" alt="image" src="https://github.com/user-attachments/assets/732aef70-3b92-493f-8871-e7380792f31b" />

### Finding notes

Ghost notes you have made can be found by using `leader + gnf` to find ALL your ghost notes, or `leader + gnF` to find ghost notes in your current project.
If you have telescope or snacks installed you will be able to preview the notes as well - see below:

<img width="1163" height="957" alt="image" src="https://github.com/user-attachments/assets/7126a2fc-4648-4d20-90f9-622d55f82ccb" />

If neither telescope nor snacks is installed you will get a simple picker that lets you see the headline and also moves you to the location of the note when picked.

---
## Install

lazy.nvim:

```lua
return {
  "vvilhelmsen/ghostnotes.nvim",
  config = function()
    require("ghostnotes").setup({
      -- Optional overrides, for example:
      -- note_prefix = "📝 ",
      -- path_options = ":p",
    })
  end,
}
````
---

## Default Keymaps

| Action             | Default         |
| ------------------ | ---------------|
| Add / View / Edit  | `<leader>gne`  |
| Clear line         | `<leader>gnc`  |
| Find global        | `<leader>gnf`  |
| Find in project    | `<leader>gnF`  |
| Grep global        | `<leader>gng`  |
| Grep in project    | `<leader>gnG`  |
| Yank note          | `<leader>gny`  |

---

MIT License
