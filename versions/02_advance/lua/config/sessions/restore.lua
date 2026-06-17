local M = {}

local session_layout = require("config.sessions.layout")
local empty_buffers = require("config.empty_buffers")

local function tabpage_windows(tab)
    return vim.tbl_filter(function(win)
        return vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == ""
    end, vim.api.nvim_tabpage_list_wins(tab))
end

function M.current_terminal_windows()
    local terminals = {}

    for tab_index, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for win_index, win in ipairs(tabpage_windows(tab)) do
            local buf = vim.api.nvim_win_get_buf(win)

            if vim.bo[buf].buftype == "terminal" then
                local cwd = vim.api.nvim_win_call(win, function()
                    return vim.fn.getcwd()
                end)

                table.insert(terminals, {
                    tab = tab_index,
                    win = win_index,
                    shell = vim.o.shell,
                    cwd = cwd,
                })
            end
        end
    end

    return terminals
end

function M.current_tree_state()
    local ok, api = pcall(require, "nvim-tree.api")

    return {
        visible = ok and api.tree.is_visible() == true,
    }
end

function M.current_floating_slots()
    local ok, floating = pcall(require, "config.floating")

    if not ok or type(floating.current_slots) ~= "function" then
        return {}
    end

    return floating.current_slots()
end

local function restore_terminals(terminals)
    if type(terminals) ~= "table" or #terminals == 0 then
        return
    end

    local ok, terminal = pcall(require, "config.terminal")

    if not ok then
        return
    end

    for _, item in ipairs(terminals) do
        local tab = vim.api.nvim_list_tabpages()[item.tab]

        if tab and vim.api.nvim_tabpage_is_valid(tab) then
            local wins = tabpage_windows(tab)
            local win = wins[item.win]

            if win and vim.api.nvim_win_is_valid(win) then
                local buf = vim.api.nvim_win_get_buf(win)

                if terminal.valid_terminal(buf) then
                    goto continue
                end

                vim.api.nvim_set_current_tabpage(tab)
                vim.api.nvim_set_current_win(win)

                if item.cwd and vim.fn.isdirectory(item.cwd) == 1 then
                    pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(item.cwd))
                end

                pcall(terminal.create_buffer_terminal)
            end
        end

        ::continue::
    end
end

local function restore_floating_slots(floating_slots)
    if type(floating_slots) ~= "table" or #floating_slots == 0 then
        return
    end

    local ok, floating = pcall(require, "config.floating")

    if not ok or type(floating.restore_slot) ~= "function" then
        return
    end

    for _, item in ipairs(floating_slots) do
        if type(item) == "table" then
            pcall(floating.restore_slot, item.slot, item.file, {
                visible = false,
            })
        end
    end
end

local function restore_tree(tree)
    if type(tree) ~= "table" or not tree.visible then
        return
    end

    local ok, api = pcall(require, "nvim-tree.api")

    if not ok then
        return
    end

    local current_win = vim.api.nvim_get_current_win()

    pcall(api.tree.open, {
        focus = false,
    })

    if vim.api.nvim_win_is_valid(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function clear_missing_file_buffers()
    local missing = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)

        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.bo[buf].buftype == ""
            and name ~= ""
            and vim.fn.filereadable(name) == 0
        then
            table.insert(missing, vim.fn.fnamemodify(name, ":~:."))

            for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
                    if
                        vim.api.nvim_win_is_valid(win)
                        and vim.api.nvim_win_get_buf(win) == buf
                    then
                        local fallback = vim.api.nvim_create_buf(false, true)

                        vim.bo[fallback].buflisted = false
                        vim.api.nvim_win_set_buf(win, fallback)
                    end
                end
            end

            pcall(vim.api.nvim_buf_delete, buf, {
                force = true,
            })
        end
    end

    if #missing > 0 then
        vim.notify("Missing session files: " .. table.concat(missing, ", "), vim.log.levels.WARN)
    end
end

function M.after_load(metadata)
    clear_missing_file_buffers()

    if session_layout.restore(metadata.layout) then
        restore_floating_slots(metadata.floating_slots)
        empty_buffers.cleanup()
        return
    end

    restore_terminals(metadata.terminals)
    restore_floating_slots(metadata.floating_slots)
    restore_tree(metadata.tree)
    empty_buffers.cleanup()
end

return M
