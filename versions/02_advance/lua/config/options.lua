vim.g.current_workspace_root = vim.fn.getcwd()
vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = "a"
vim.opt.splitright = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = false

vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:block,r-cr-o:block,a:blinkwait700-blinkoff400-blinkon250"

vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
