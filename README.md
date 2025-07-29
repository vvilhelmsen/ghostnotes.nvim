````markdown
# 👻 ghostnotes.nvim

Add simple, persistent virtual notes to any line in your code. Project-scoped (in git repos) or global.

---

## Features

- Add/edit/clear notes on any line
- Project or global storage (JSON)
- Quick navigation to all notes using snacks

---

## Install

<details>
<summary>lazy.nvim example</summary>

```lua
{
  "vvilhelmsen/ghostnotes.nvim",
  config = function()
    require("ghostnotes").config()
  end,
}
````

</details>

---

## Keymaps

| Action       | Default       |
| ------------ | ------------- |
| Add          | `<leader>gna` |
| Edit         | `<leader>gne` |
| Clear line   | `<leader>gnc` |
| Find global  | `<leader>gnf` |
| Find project | `<leader>gnF` |

---

## Usage

* Place cursor, add/edit/clear note with mapped keys
* Use find commands to jump to notes

---

## How it works

* Notes are stored as JSON in your git repo or globally
* No file changes—ghost notes only appear as virtual text

---

MIT License
