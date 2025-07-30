# 👻 ghostnotes.nvim

Add simple, persistent virtual notes to any line in your code. Markdown supported.

Contributions are welcome!

---
## Table of Contents

- [Example](#example)
- [Install](#install)
- [Default Keymaps](#default-keymaps)
- [How it works](#how-it-works)
- [License](#mit-license)

---

## Example

### Adding a note

<img width="1770" height="1054" alt="image" src="https://github.com/user-attachments/assets/c7d70b15-3e4d-4875-8da0-b4c02dedc3fc" />

### Finding notes

<img width="912" height="147" alt="image" src="https://github.com/user-attachments/assets/bb684922-719e-4371-8f24-97dc1d40b31b" />

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
