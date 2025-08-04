# 👻 ghostnotes.nvim

Add simple, persistent virtual notes to any line in your code. Markdown supported.
(Snacks or Telescope is needed for preview to work)

Contributions are welcome!

---
## Table of Contents

- [Example](#example)
- [Install](#install)
- [Default Keymaps](#default-keymaps)
- [How it works](#how-it-works)

---

## Example

### Adding a note

<img width="1162" height="967" alt="image" src="https://github.com/user-attachments/assets/732aef70-3b92-493f-8871-e7380792f31b" />

### Finding notes

<img width="1163" height="957" alt="image" src="https://github.com/user-attachments/assets/7126a2fc-4648-4d20-90f9-622d55f82ccb" />

---
## Install

lazy.nvim:

```lua
return {
  "vvilhelmsen/ghostnotes.nvim",
  config = function()
    require("ghostnotes").config()
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
| Yank note          | `<leader>gny`  |

---

## How it works

* Notes are stored as JSON in your git repo and globally
* No file changes - ghost notes only appear as virtual text

---

MIT License
