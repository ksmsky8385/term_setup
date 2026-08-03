vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

vim.cmd([[nnoremenu <silent> 500.10 PopUp.Toggle\ Mode <Cmd>startinsert<CR>]])
vim.cmd([[inoremenu <silent> 500.10 PopUp.Toggle\ Mode <Cmd>stopinsert<CR>]])

local floating = require("config.floating")
local empty_buffers = require("config.empty_buffers")

local function is_nvim_tree()
    return vim.bo.filetype == "NvimTree"
end

local function empty_unlisted_buffer()
    vim.cmd("enew")
    vim.bo.buflisted = false
end

local function vertical_split_or_empty()
    if floating.reject_window_action() then
        return
    end

    require("config.window_picker").remember_window()
    vim.cmd("rightbelow vsplit")
    empty_unlisted_buffer()
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

local function horizontal_split_or_empty()
    if floating.reject_window_action() then
        return
    end

    require("config.window_picker").remember_window()
    vim.cmd("rightbelow split")
    empty_unlisted_buffer()
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

local function open_dashboard_home()
    pcall(vim.cmd, "DashboardHome")
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
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
    NvimTree = true,
    alpha = true,
    notify = true,
}

local ignored_save_filetypes = {
    NvimTree = true,
    TelescopePreview = true,
    TelescopePrompt = true,
    TelescopeResults = true,
    alpha = true,
    lazygit = true,
    notify = true,
}

local function is_agentic_filetype(filetype)
    return type(filetype) == "string" and filetype:match("^Agentic") ~= nil
end

local function restore_insert_mode(was_insert, buf)
    if not was_insert then
        return
    end

    vim.schedule(function()
        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.api.nvim_get_current_buf() == buf
            and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i"
        then
            vim.cmd("startinsert")
        end
    end)
end

local function saveable_regular_buffer(buf)
    return vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].modifiable
        and not ignored_save_filetypes[vim.bo[buf].filetype]
end

local function prompt_saveas_name()
    vim.fn.inputsave()
    local ok, filename = pcall(vim.fn.input, "Save as: ", "", "file")
    vim.fn.inputrestore()

    if not ok then
        return nil
    end

    filename = vim.trim(filename or "")

    if filename == "" then
        return nil
    end

    return filename
end

local function save_current_file()
    local buf = vim.api.nvim_get_current_buf()
    local was_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"

    if not saveable_regular_buffer(buf) then
        restore_insert_mode(was_insert, buf)
        return
    end

    local name = vim.api.nvim_buf_get_name(buf)
    local ok
    local err

    if name == "" then
        local filename = prompt_saveas_name()

        if not filename or vim.api.nvim_get_current_buf() ~= buf then
            restore_insert_mode(was_insert, buf)
            return
        end

        ok, err = pcall(vim.cmd, "saveas " .. vim.fn.fnameescape(filename))
    else
        ok, err = pcall(vim.cmd, "write")
    end

    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
    end

    restore_insert_mode(was_insert, buf)
end

local function is_ignored_quit_window(win)
    if not vim.api.nvim_win_is_valid(win) then
        return true
    end

    local buf = vim.api.nvim_win_get_buf(win)
    local filetype = vim.bo[buf].filetype

    return ignored_quit_filetypes[filetype] == true or is_agentic_filetype(filetype)
end

local function close_target_window_count()
    local count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if
                filetype ~= "FloatingSlot"
                and filetype ~= "NvimTree"
                and filetype ~= "notify"
                and not is_agentic_filetype(filetype)
            then
                count = count + 1
            end
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
    if close_target_window_count() > 1 then
        pcall(vim.api.nvim_win_close, current_win, true)
    else
        open_dashboard_home()
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

local function return_buffer_to_dashboard(buf, force)
    local was_running = false

    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
        local job_id = vim.b[buf].terminal_job_id

        was_running = terminal_job_running(buf)

        if was_running then
            pcall(vim.fn.jobstop, job_id)
        end
    end

    open_dashboard_home()

    local dashboard_buf = vim.api.nvim_get_current_buf()

    if
        vim.api.nvim_buf_is_valid(buf)
        and buf ~= dashboard_buf
        and vim.bo[buf].filetype ~= "alpha"
    then
        pcall(vim.api.nvim_buf_delete, buf, {
            force = force or was_running,
        })
    end

    empty_buffers.cleanup({
        keep = { dashboard_buf },
    })
end

local function leader_quit(force)
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()

    if floating.close_current(force) then
        return
    end

    if force and vim.bo[current_buf].buftype == "terminal" then
        local replaced = buffers.delete_current_to_hidden(force)

        if replaced ~= nil then
            return
        end

        if close_target_window_count() <= 1 then
            return_buffer_to_dashboard(current_buf, force)
            return
        end

        terminal.kill_current_terminal({
            force = force,
            replace = false,
        })

        if vim.api.nvim_win_is_valid(current_win) then
            if close_target_window_count() > 1 then
                pcall(vim.api.nvim_win_close, current_win, true)
            else
                open_dashboard_home()
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

    if
        empty_buffers.is_deletable(current_buf)
        and not vim.bo[current_buf].buflisted
        and close_target_window_count() > 1
    then
        local closed = pcall(vim.api.nvim_win_close, current_win, true)

        if closed and vim.api.nvim_buf_is_valid(current_buf) then
            pcall(vim.api.nvim_buf_delete, current_buf, {
                force = true,
            })
        end

        return
    end

    if close_target_window_count() > 1 then
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

    return_buffer_to_dashboard(current_buf, force)
end

vim.keymap.set("n", "<leader>h", function()
    if is_nvim_tree() then
        return
    end

    open_dashboard_home()
end, {
    noremap = true,
    silent = true,
    desc = "Open dashboard in current window",
})

vim.keymap.set("n", "<leader>?", function()
    if is_nvim_tree() then
        return
    end

    require("config.about").toggle_floating()
end, {
    noremap = true,
    silent = true,
    desc = "Toggle About Neovim",
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

vim.api.nvim_create_autocmd("TermOpen", {
    callback = function(args)
        vim.schedule(function()
            if
                vim.api.nvim_buf_is_valid(args.buf)
                and vim.bo[args.buf].buftype == "terminal"
            then
                vim.keymap.set("n", "<leader>tc", terminal.clear_current_terminal, {
                    buffer = args.buf,
                    noremap = true,
                    silent = true,
                    desc = "Reset terminal buffer",
                })
            end
        end)
    end,
})

vim.keymap.set("n", "<leader>`", function()
    floating.toggle("`")
end, {
    noremap = true,
    silent = true,
    desc = "Toggle floating slot ~",
})

vim.keymap.set("n", "<leader>~", function()
    floating.toggle("`")
end, {
    noremap = true,
    silent = true,
    desc = "Toggle floating slot ~",
})

for slot = 0, 9 do
    vim.keymap.set("n", "<leader>" .. slot, function()
        floating.toggle(slot)
    end, {
        noremap = true,
        silent = true,
        desc = "Toggle floating slot " .. slot,
    })
end

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

vim.keymap.set("n", "<leader><Tab>q", tabs.close, {
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

vim.keymap.set("n", "<leader><Esc>", "<Cmd>DashboardQuit<CR>", {
    noremap = true,
    silent = true,
    desc = "Safely quit Neovim",
})

vim.keymap.set("n", "<leader>q", function()
    leader_quit(false)
end, {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

vim.keymap.set("n", "<leader>Q", function()
    leader_quit(true)
end, {
    noremap = true,
    silent = true,
    desc = "Force close current window",
})

vim.keymap.set("n", "<leader><C-s>", function()
    settings.open()
end, {
    noremap = true,
    silent = true,
    desc = "Open settings",
})

vim.keymap.set({ "n", "i" }, "<C-s>", save_current_file, {
    noremap = true,
    silent = true,
    desc = "Save file",
})

vim.keymap.set("n", "<leader>bb", buffers.pick_current, {
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

vim.keymap.set("n", "<leader>bm", function()
    if floating.reject_window_action() then
        return
    end

    buffers.move_current_to_window()
end, {
    noremap = true,
    silent = true,
    desc = "Move current buffer to picked window",
})

vim.keymap.set("n", "<leader>bw", function()
    if floating.reject_window_action() then
        return
    end

    buffers.open_current_in_window()
end, {
    noremap = true,
    silent = true,
    desc = "Show current buffer in picked window",
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

vim.keymap.set("n", "<leader>wr", function()
    window_picker.swap_current_window_label({
        filetype = {
            "NvimTree",
            "notify",
        },
    })
end, {
    noremap = true,
    silent = true,
    desc = "Swap current window label",
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

vim.keymap.set("n", "<leader>wq", function()
    close_current_window_or_dashboard(vim.api.nvim_get_current_win())
end, {
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

vim.keymap.set("i", "<C-Left>", "<Esc><C-w>h", { noremap = true, silent = true })
vim.keymap.set("i", "<C-Down>", "<Esc><C-w>j", { noremap = true, silent = true })
vim.keymap.set("i", "<C-Up>", "<Esc><C-w>k", { noremap = true, silent = true })
vim.keymap.set("i", "<C-Right>", "<Esc><C-w>l", { noremap = true, silent = true })

vim.keymap.set("n", "<A-Left>", ":vertical resize -1<CR>", { silent = true })
vim.keymap.set("n", "<A-Right>", ":vertical resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-Up>", ":resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-Down>", ":resize -1<CR>", { silent = true })

vim.keymap.set("n", "<A-h>", ":vertical resize -1<CR>", { silent = true })
vim.keymap.set("n", "<A-l>", ":vertical resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-k>", ":resize +1<CR>", { silent = true })
vim.keymap.set("n", "<A-j>", ":resize -1<CR>", { silent = true })
