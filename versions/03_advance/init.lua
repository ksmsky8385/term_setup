vim.opt.title = true
vim.opt.titlestring = [[%{getcwd() == expand('~') ? 'nvim' : 'nvim: ' . fnamemodify(getcwd(), ':t')}]]

require("config.options")
require("config.paths")
require("config.autocmds")
require("config.editor_settings").setup()
require("config.terminal").setup()
require("config.external_changes").setup()
require("config.autosave").setup()
require("config.buffers.auto_close").setup()
require("config.end_of_buffer").setup()
require("config.keymaps")
require("config.commands")
require("config.lazy")
require("config.leader_prefixes").setup()
require("config.themes").apply_saved()
