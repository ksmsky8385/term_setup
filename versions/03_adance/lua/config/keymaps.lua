vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

local function is_nvim_tree()
    return vim.bo.filetype == "NvimTree"
end

local function vertical_split_or_empty()
    vim.cmd("rightbelow vsplit")

    if is_nvim_tree() then
        vim.cmd("enew")
    end
end

local function horizontal_split_or_empty()
    vim.cmd("rightbelow split")

    if is_nvim_tree() then
        vim.cmd("enew")
    end
end

vim.keymap.set("n", "<leader>h", function()
    if is_nvim_tree() then
        return
    end

    pcall(vim.cmd, "DashboardHome")
end, {
    noremap = true,
    silent = true,
    desc = "Open dashboard in current window",
})

vim.keymap.set("n", "<leader>t", require("config.terminal").toggle_window_terminal, {
    noremap = true,
    silent = true,
    desc = "Toggle terminal in current window",
})

vim.keymap.set("n", "<leader>T", require("config.terminal").pick_terminal, {
    noremap = true,
    silent = true,
    desc = "Pick running terminal",
})

vim.keymap.set("n", "<leader>sv", function()
    vertical_split_or_empty()
end, {
    noremap = true,
    silent = true,
    desc = "Vertical split",
})

vim.keymap.set("n", "<leader>sh", function()
    horizontal_split_or_empty()
end, {
    noremap = true,
    silent = true,
    desc = "Horizontal split",
})

vim.keymap.set("n", "<leader>sq", ":close<CR>", {
    noremap = true,
    silent = true,
    desc = "Close split",
})

vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<C-Left>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Up>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<A-Left>", ":vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<A-Right>", ":vertical resize +2<CR>", { silent = true })
vim.keymap.set("n", "<A-Up>", ":resize +2<CR>", { silent = true })
vim.keymap.set("n", "<A-Down>", ":resize -2<CR>", { silent = true })
