vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

vim.keymap.set("t", "<C-[>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

vim.keymap.set("n", "<leader><leader>", function()
    return vim.bo.buftype == "" and vim.bo.modifiable and "i" or "<Ignore>"
end, {
    expr = true,
    noremap = true,
    silent = true,
    desc = "Enter insert mode in file buffer",
})

vim.cmd([[nnoremenu <silent> 500.10 PopUp.Toggle\ Mode <Cmd>startinsert<CR>]])
vim.cmd([[inoremenu <silent> 500.10 PopUp.Toggle\ Mode <Cmd>stopinsert<CR>]])

vim.keymap.set("n", "<Tab>", function()
    require("config.file_path").toggle()
end, {
    silent = true,
    desc = "Toggle current file path preview",
})

local floating = require("config.floating")
local empty_buffers = require("config.empty_buffers")

local function is_agentic_filetype(filetype)
    return type(filetype) == "string" and filetype:match("^Agentic") ~= nil
end

local function reject_agentic_window_action()
    if not is_agentic_filetype(vim.bo.filetype) then
        return false
    end

    vim.notify("Agentic windows are separate from editor window actions.", vim.log.levels.INFO)
    return true
end

local function is_nvim_tree()
    return vim.bo.filetype == "NvimTree"
end

local function empty_unlisted_buffer()
    vim.cmd("enew")
    vim.bo.buflisted = false
end

local function vertical_split_or_empty()
    if floating.split("vertical") then return end
    if floating.reject_window_action() or reject_agentic_window_action() then
        return
    end

    require("config.window_picker").remember_window()
    vim.cmd("rightbelow vsplit")
    empty_unlisted_buffer()
    require("config.winbar").clear_window(vim.api.nvim_get_current_win())
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

local function horizontal_split_or_empty()
    if floating.split("horizontal") then return end
    if floating.reject_window_action() or reject_agentic_window_action() then
        return
    end

    require("config.window_picker").remember_window()
    vim.cmd("rightbelow split")
    empty_unlisted_buffer()
    require("config.winbar").clear_window(vim.api.nvim_get_current_win())
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

local function popup_split(direction)
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_win_get_config(0).relative ~= ""
        or is_nvim_tree() or is_agentic_filetype(vim.bo[buf].filetype)
        or (vim.bo[buf].buftype ~= "" and vim.bo[buf].buftype ~= "terminal") then
        return
    end
    if direction == "vertical" then vertical_split_or_empty() else horizontal_split_or_empty() end
end

vim.api.nvim_create_user_command("WindowSplitVertical", function() popup_split("vertical") end, {})
vim.api.nvim_create_user_command("WindowSplitHorizontal", function() popup_split("horizontal") end, {})
vim.cmd([[nnoremenu <silent> 500.20 PopUp.Split\ Vertical <Cmd>WindowSplitVertical<CR>]])
vim.cmd([[inoremenu <silent> 500.20 PopUp.Split\ Vertical <Cmd>WindowSplitVertical<CR>]])
vim.cmd([[nnoremenu <silent> 500.21 PopUp.Split\ Horizontal <Cmd>WindowSplitHorizontal<CR>]])
vim.cmd([[inoremenu <silent> 500.21 PopUp.Split\ Horizontal <Cmd>WindowSplitHorizontal<CR>]])

local function open_dashboard_home()
    pcall(vim.cmd, "DashboardHome")
    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

local function only_non_tree_window()
    if is_nvim_tree() or reject_agentic_window_action() then
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

local function close_target_window_count(tabpage)
    local count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage or 0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if
                vim.api.nvim_win_get_config(win).relative == ""
                and not vim.wo[win].previewwindow
                and filetype ~= "FloatingSlot"
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
    if not vim.api.nvim_win_is_valid(current_win) then return end
    if close_target_window_count(vim.api.nvim_win_get_tabpage(current_win)) > 1 then
        pcall(vim.api.nvim_win_close, current_win, true)
    else
        vim.api.nvim_set_current_win(current_win)
        open_dashboard_home()
    end
end

require("config.winbar").on_empty = close_current_window_or_dashboard

local popup_close_window

local function can_close_from_popup(win)
    return win and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_config(win).relative == ""
        and not is_ignored_quit_window(win)
        and close_target_window_count() > 1
end

vim.api.nvim_create_user_command("WindowCloseFromPopup", function()
    local win = popup_close_window or vim.api.nvim_get_current_win()
    if can_close_from_popup(win) then
        close_current_window_or_dashboard(win)
    end
end, {})

vim.api.nvim_create_autocmd("MenuPopup", {
    group = vim.api.nvim_create_augroup("ConfigPopupWindowClose", { clear = true }),
    callback = function()
        local mouse = vim.fn.getmousepos()
        popup_close_window = mouse.winid ~= 0 and mouse.winid or vim.api.nvim_get_current_win()
        if can_close_from_popup(popup_close_window) then
            vim.cmd([[nnoremenu <silent> 500.22 PopUp.Close\ Window <Cmd>WindowCloseFromPopup<CR>]])
            vim.cmd([[inoremenu <silent> 500.22 PopUp.Close\ Window <Cmd>WindowCloseFromPopup<CR>]])
        else
            pcall(vim.cmd, [[aunmenu PopUp.Close\ Window]])
        end
    end,
})

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

    if require('config.editor_settings').get('winbar') and not is_ignored_quit_window(current_win)
        and (vim.bo[current_buf].buftype == '' or vim.bo[current_buf].buftype == 'terminal') then
        local bar = require('config.winbar')
        bar.track(current_win)
        local function close_if_empty()
            if vim.api.nvim_win_is_valid(current_win) and #bar.items(current_win) == 0 then
                close_current_window_or_dashboard(current_win)
            end
        end
        if vim.tbl_contains(bar.items(current_win), current_buf) then
            bar.close(current_win, current_buf, force, close_if_empty)
        elseif #bar.items(current_win) > 0 then
            bar.select(current_win, bar.items(current_win)[1])
        else
            close_if_empty()
        end
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
                vim.keymap.set("n", "<leader><leader>", "<Cmd>startinsert<CR>", {
                    buffer = args.buf,
                    noremap = true,
                    silent = true,
                    desc = "Enter terminal mode",
                })

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

vim.keymap.set("n", "<leader><Esc>", function()
    vim.cmd("DashboardQuit")
end, {
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

for _, binding in ipairs({ {"h", -1}, {"<Left>", -1}, {"l", 1}, {"<Right>", 1} }) do
    vim.keymap.set("n", "<leader>b" .. binding[1], function()
        require("config.winbar").cycle(binding[2])
    end, { silent = true, desc = "Switch adjacent winbar buffer" })
end
for _, binding in ipairs({ {"H", -1}, {"L", 1} }) do
    vim.keymap.set("n", "<leader>b" .. binding[1], function()
        require("config.winbar").move_current(binding[2])
    end, { silent = true, desc = "Reorder current winbar buffer" })
end

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

vim.keymap.set("n", "<leader>bc", function()
    require("config.winbar").clean_current()
end, {
    noremap = true,
    silent = true,
    desc = "Clean current winbar (keep active, modified and terminal buffers)",
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

vim.keymap.set("n", "<leader>wl", function()
    if floating.is_slot_window() then return end
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

vim.keymap.set("n", "<leader>wr", function()
    if floating.reset_layout() then return end
    local current = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == '' then
            vim.api.nvim_win_call(win, function() vim.cmd('wincmd =') end)
            break
        end
    end
    if vim.api.nvim_win_is_valid(current) then vim.api.nvim_set_current_win(current) end
end, {noremap = true, silent = true, desc = "Reset window layouts"})

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
    if floating.close_current(false) then return end
    close_current_window_or_dashboard(vim.api.nvim_get_current_win())
end, {
    noremap = true,
    silent = true,
    desc = "Close current window",
})

local function focus_or_float(direction, normal)
    return function()
        if require("config.tree_focus").focus(direction) then return end
        if not floating.focus(direction) then vim.cmd("wincmd " .. normal) end
    end
end

vim.keymap.set("n", "<C-h>", focus_or_float("left", "h"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", focus_or_float("down", "j"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", focus_or_float("up", "k"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", focus_or_float("right", "l"), { noremap = true, silent = true })

vim.keymap.set("n", "<C-Left>", focus_or_float("left", "h"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-Down>", focus_or_float("down", "j"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-Up>", focus_or_float("up", "k"), { noremap = true, silent = true })
vim.keymap.set("n", "<C-Right>", focus_or_float("right", "l"), { noremap = true, silent = true })

local function insert_focus_or_float(direction, normal)
    return function()
        vim.cmd("stopinsert")
        vim.schedule(focus_or_float(direction, normal))
    end
end

vim.keymap.set("i", "<C-Left>", insert_focus_or_float("left", "h"), { noremap = true, silent = true })
vim.keymap.set("i", "<C-Down>", insert_focus_or_float("down", "j"), { noremap = true, silent = true })
vim.keymap.set("i", "<C-Up>", insert_focus_or_float("up", "k"), { noremap = true, silent = true })
vim.keymap.set("i", "<C-Right>", insert_focus_or_float("right", "l"), { noremap = true, silent = true })

local function terminal_focus_or_float(direction, normal)
    return function()
        local leave_terminal = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
        vim.api.nvim_feedkeys(leave_terminal, "n", false)
        vim.schedule(focus_or_float(direction, normal))
    end
end

vim.keymap.set("t", "<C-h>", terminal_focus_or_float("left", "h"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-j>", terminal_focus_or_float("down", "j"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-k>", terminal_focus_or_float("up", "k"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-l>", terminal_focus_or_float("right", "l"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-Left>", terminal_focus_or_float("left", "h"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-Down>", terminal_focus_or_float("down", "j"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-Up>", terminal_focus_or_float("up", "k"), { noremap = true, silent = true })
vim.keymap.set("t", "<C-Right>", terminal_focus_or_float("right", "l"), { noremap = true, silent = true })

local function resize_or_float(direction, delta, command)
    return function()
        if not floating.resize(direction, delta) then vim.cmd(command) end
    end
end

vim.keymap.set("n", "<A-Left>", resize_or_float("left", -1, "vertical resize -1"), { silent = true })
vim.keymap.set("n", "<A-Right>", resize_or_float("right", 1, "vertical resize +1"), { silent = true })
vim.keymap.set("n", "<A-Up>", resize_or_float("up", 1, "resize +1"), { silent = true })
vim.keymap.set("n", "<A-Down>", resize_or_float("down", -1, "resize -1"), { silent = true })

vim.keymap.set("n", "<A-h>", resize_or_float("left", -1, "vertical resize -1"), { silent = true })
vim.keymap.set("n", "<A-l>", resize_or_float("right", 1, "vertical resize +1"), { silent = true })
vim.keymap.set("n", "<A-k>", resize_or_float("up", 1, "resize +1"), { silent = true })
vim.keymap.set("n", "<A-j>", resize_or_float("down", -1, "resize -1"), { silent = true })
