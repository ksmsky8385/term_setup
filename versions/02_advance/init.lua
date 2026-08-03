vim.opt.title = true
vim.opt.titlestring =
    "%{&buftype ==# 'terminal' ? fnamemodify(&shell, ':t') . ' - nvim' : (&buftype ==# '' && expand('%:t') !=# '' ? expand('%:t') . ' - nvim' : 'nvim')}"

require("config.options")
require("config.paths")
require("config.autocmds")
require("config.autosave").setup()
require("config.buffers.auto_close").setup()
require("config.end_of_buffer").setup()
require("config.keymaps")
require("config.commands")
require("config.lazy")
require("config.leader_prefixes").setup()
require("config.themes").apply_saved()
