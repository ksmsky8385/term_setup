vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

local function stop_terminal_insert()
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
        "n",
        false
    )
end

local function is_nvim_tree()
    return vim.bo.filetype == "NvimTree"
end

local function empty_unlisted_buffer()
    vim.cmd("enew")
    vim.bo.buflisted = false
end

local function vertical_split_or_empty()
    require("config.window_picker").remember_window()
    vim.cmd("rightbelow vsplit")
    empty_unlisted_buffer()
end

local function horizontal_split_or_empty()
    require("config.window_picker").remember_window()
    vim.cmd("rightbelow split")
    empty_unlisted_buffer()
end

local function only_non_tree_window()
    if is_nvim_tree() then
        return
    end

    vim.cmd("only")
end

local buffers = require("config.buffers")
local sessions = require("config.sessions")
local settings = require("config.settings")
local tabs = require("config.tabs")
local terminal = require("config.terminal")
local window_picker = require("config.window_picker")

tabs.setup()
if window_picker.setup then
    window_picker.setup()
end

local ignored_quit_filetypes = {
    FloatingTerminal = true,
    NvimTree = true,
    alpha = true,
    notify = true,
}

local function is_ignored_quit_window(win)
    if not vim.api.nvim_win_is_valid(win) then
        return true
    end

    local buf = vim.api.nvim_win_get_buf(win)

    return ignored_quit_filetypes[vim.bo[buf].filetype] == true
end

local function regular_window_count()
    local count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not is_ignored_quit_window(win) then
            count = count + 1
        end
    end

    return count
end

local function buffer_visible_in_other_window(buf, current_win)
    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if
            win ~= current_win
            and vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_buf(win) == buf
        then
            return true
        end
    end

    return false
end

local function close_current_window_or_dashboard(current_win)
    if regular_window_count() > 1 then
        pcall(vim.api.nvim_win_close, current_win, true)
    else
        pcall(vim.cmd, "DashboardHome")
    end
end

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function close_blocker(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end

    if vim.bo[buf].modified and not force then
        return "Buffer has unsaved changes. Use Space Q to force."
    end

    if vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) and not force then
        return "Terminal process is still running. Use Space Q to force."
    end

    return nil
end

local function return_last_window_to_dashboard(force)
    local old_buf = vim.api.nvim_get_current_buf()

    pcall(vim.cmd, "DashboardHome")

    if
        vim.api.nvim_buf_is_valid(old_buf)
        and old_buf ~= vim.api.nvim_get_current_buf()
        and vim.bo[old_buf].filetype ~= "alpha"
    then
        pcall(vim.api.nvim_buf_delete, old_buf, {
            force = force,
        })
    end
end

local function leader_quit(force)
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()

    if force and vim.bo[current_buf].buftype == "terminal" then
        if terminal.is_float_terminal(current_buf) then
            terminal.kill_current_terminal(force)
            return
        end

        local replaced = buffers.delete_current_to_hidden(force)

        if replaced ~= nil then
            return
        end

        terminal.kill_current_terminal({
            force = force,
            replace = false,
        })

        if vim.api.nvim_win_is_valid(current_win) then
            if regular_window_count() > 1 then
                pcall(vim.api.nvim_win_close, current_win, true)
            else
                pcall(vim.cmd, "DashboardHome")
            end
        end

        return
    end

    if is_ignored_quit_window(current_win) then
        return
    end

    if buffer_visible_in_other_window(current_buf, current_win) then
        close_current_window_or_dashboard(current_win)
        return
    end

    local replaced = buffers.delete_current_to_hidden(force)

    if replaced ~= nil then
        return
    end

    if regular_window_count() > 1 then
        if not buffers.delete_current(force) then
            return
        end

        vim.cmd(force and "quit!" or "quit")
        return
    end

    local blocker = close_blocker(current_buf, force)

    if blocker then
        vim.notify(blocker, vim.log.levels.WARN)
        return
    end

    return_last_window_to_dashboard(force)
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

vim.keymap.set("n", "<leader>tt", terminal.create_buffer_terminal, {
    noremap = true,
    silent = true,
    desc = "Create buffer terminal",
})

vim.keymap.set("n", "<leader>ts", function()
    terminal.create_buffer_terminal_split("rightbelow split")
end, {
    noremap = true,
    silent = true,
    desc = "Create buffer terminal in horizontal split",
})

vim.keymap.set("n", "<leader>tv", function()
    terminal.create_buffer_terminal_split("rightbelow vsplit")
end, {
    noremap = true,
    silent = true,
    desc = "Create buffer terminal in vertical split",
})

vim.keymap.set("n", "<leader>`", terminal.open_float_terminal, {
    noremap = true,
    silent = true,
    desc = "Toggle floating terminal",
})

vim.keymap.set("n", "<leader><Tab><Tab>", tabs.pick, {
    noremap = true,
    silent = true,
    desc = "Pick tab",
})

vim.keymap.set("n", "<leader><Tab>n", tabs.new, {
    noremap = true,
    silent = true,
    desc = "New tab",
})

vim.keymap.set("n", "<leader><Tab>c", tabs.close, {
    noremap = true,
    silent = true,
    desc = "Close tab",
})

vim.keymap.set("n", "<leader><Tab>h", tabs.previous, {
    noremap = true,
    silent = true,
    desc = "Previous tab",
})

vim.keymap.set("n", "<leader><Tab><Left>", tabs.previous, {
    noremap = true,
    silent = true,
    desc = "Previous tab",
})

vim.keymap.set("n", "<leader><Tab>l", tabs.next, {
    noremap = true,
    silent = true,
    desc = "Next tab",
})

vim.keymap.set("n", "<leader><Tab><Right>", tabs.next, {
    noremap = true,
    silent = true,
    desc = "Next tab",
})

vim.keymap.set("n", "<leader><C-q>", ":q<CR>", {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

vim.keymap.set("t", "<leader><C-q>", "<C-\\><C-n><cmd>q<CR>", {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

vim.keymap.set("n", "<leader>q", function()
    leader_quit(false)
end, {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

vim.keymap.set("t", "<leader>q", function()
    stop_terminal_insert()
    vim.schedule(function()
        leader_quit(false)
    end)
end, {
    noremap = true,
    silent = true,
    desc = "Close current terminal window",
})

vim.keymap.set("n", "<leader>Q", function()
    leader_quit(true)
end, {
    noremap = true,
    silent = true,
    desc = "Force close current window",
})

vim.keymap.set("t", "<leader>Q", function()
    stop_terminal_insert()
    vim.schedule(function()
        leader_quit(true)
    end)
end, {
    noremap = true,
    silent = true,
    desc = "Force close current terminal",
})

vim.keymap.set("n", "<leader><C-s>", function()
    settings.open()
end, {
    noremap = true,
    silent = true,
    desc = "Open settings",
})

vim.keymap.set("n", "<leader>bb", buffers.pick, {
    noremap = true,
    silent = true,
    desc = "Pick buffer",
})

vim.keymap.set("n", "<leader>bn", buffers.next, {
    noremap = true,
    silent = true,
    desc = "Next buffer",
})

vim.keymap.set("n", "<leader>bp", buffers.previous, {
    noremap = true,
    silent = true,
    desc = "Previous buffer",
})

vim.keymap.set("n", "<leader>bd", function()
    buffers.delete_current(false)
end, {
    noremap = true,
    silent = true,
    desc = "Delete current buffer",
})

vim.keymap.set("n", "<leader>bD", function()
    buffers.delete_current(true)
end, {
    noremap = true,
    silent = true,
    desc = "Force delete current buffer",
})

vim.keymap.set("n", "<leader>bo", function()
    buffers.delete_others(false)
end, {
    noremap = true,
    silent = true,
    desc = "Delete other buffers",
})

vim.keymap.set("n", "<leader>bO", function()
    buffers.delete_others(true)
end, {
    noremap = true,
    silent = true,
    desc = "Force delete other buffers",
})

for _, slot in ipairs(sessions.configured_slot_ids()) do
    vim.keymap.set("n", "<leader>P" .. slot, function()
        sessions.save(slot)
    end, {
        noremap = true,
        silent = true,
        desc = "Save session " .. slot,
    })

    vim.keymap.set("n", "<leader>p" .. slot, function()
        sessions.load(slot)
    end, {
        noremap = true,
        silent = true,
        desc = "Load session " .. slot,
    })
end

vim.keymap.set("n", "<leader>pp", sessions.pick, {
    noremap = true,
    silent = true,
    desc = "Pick session",
})

vim.keymap.set("n", "<leader>ww", window_picker.focus_window, {
    noremap = true,
    silent = true,
    desc = "Focus window",
})

vim.keymap.set("n", "<leader>wv", function()
    vertical_split_or_empty()
end, {
    noremap = true,
    silent = true,
    desc = "Vertical split",
})

vim.keymap.set("n", "<leader>ws", function()
    horizontal_split_or_empty()
end, {
    noremap = true,
    silent = true,
    desc = "Horizontal split",
})

vim.keymap.set("n", "<leader>wo", only_non_tree_window, {
    noremap = true,
    silent = true,
    desc = "Close other windows",
})

vim.keymap.set("n", "<leader>wq", ":q<CR>", {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<C-Left>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Up>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<A-Left>", ":vertical resize -1<CR>", { silent = true })
vim.keymap.set("n", "<A-Right>", ":vertical resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-Up>", ":resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-Down>", ":resize -1<CR>", { silent = true })

vim.keymap.set("n", "<A-h>", ":vertical resize -1<CR>", { silent = true })
vim.keymap.set("n", "<A-l>", ":vertical resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-k>", ":resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-j>", ":resize -1<CR>", { silent = true })
