local buffers = require("config.floating.buffers")
local state = require("config.floating.state")

local M = {}

local AUGROUP_PREFIX = "ConfigFloatingSlot"

local function floating_size()
    local width = math.floor(vim.o.columns * 0.82)
    local height = math.floor(vim.o.lines * 0.72)

    width = math.max(width, 60)
    height = math.max(height, 12)
    width = math.min(width, vim.o.columns - 4)
    height = math.min(height, vim.o.lines - 4)

    return width, height
end

local function floating_config(slot_id)
    local width, height = floating_size()

    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " [F" .. slot_id .. "] ",
        title_pos = "center",
    }
end

local function title_for_buffer(slot_id, buf)
    local name = "Dashboard"

    if state.valid_buffer(buf) then
        local path = vim.api.nvim_buf_get_name(buf)

        if path ~= "" then
            name = vim.fn.fnamemodify(path, ":t")
        elseif vim.bo[buf].filetype ~= "alpha" and vim.bo[buf].filetype ~= state.SLOT_FILETYPE then
            name = "[No Name]"
        end
    end

    return " [F" .. slot_id .. "] " .. name .. " "
end

function M.update_title(slot_id)
    local item = state.slots[slot_id]

    if not item or not state.valid_window(item.win) then
        return
    end

    pcall(vim.api.nvim_win_set_config, item.win, {
        title = title_for_buffer(slot_id, vim.api.nvim_win_get_buf(item.win)),
        title_pos = "center",
    })
end

local function configure_window(win)
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "yes"
end

function M.save_view(item)
    if not state.valid_window(item.win) then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    local ok_set = pcall(vim.api.nvim_set_current_win, item.win)

    if not ok_set then
        return
    end

    local ok_view, view = pcall(vim.fn.winsaveview)
    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, item.win)

    if ok_view then
        item.view = view
    end

    if ok_cursor then
        item.cursor = cursor
    end

    if state.valid_window(current_win) and current_win ~= item.win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

function M.restore_view(item)
    if not state.valid_window(item.win) then
        return
    end

    if item.cursor then
        pcall(vim.api.nvim_win_set_cursor, item.win, item.cursor)
    end

    if item.view then
        local current_win = vim.api.nvim_get_current_win()
        local ok_set = pcall(vim.api.nvim_set_current_win, item.win)

        if ok_set then
            pcall(vim.fn.winrestview, item.view)
        end

        if state.valid_window(current_win) and current_win ~= item.win then
            pcall(vim.api.nvim_set_current_win, current_win)
        end
    end
end

function M.hide_slot(slot_id)
    local item = state.slots[slot_id]

    if not item or not state.valid_window(item.win) then
        return
    end

    M.save_view(item)
    pcall(vim.api.nvim_win_close, item.win, true)
    item.win = nil
    buffers.cleanup_hidden_listed_empty()
end

function M.hide_other_slots(active_slot_id)
    for slot_id in pairs(state.slots) do
        if slot_id ~= active_slot_id then
            M.hide_slot(slot_id)
        end
    end
end

function M.open(slot_id, buf)
    local item = state.slot(slot_id)
    local win = vim.api.nvim_open_win(buf, true, floating_config(slot_id))

    item.win = win
    item.buf = buf
    state.mark_window(win, slot_id)
    state.mark_buffer(buf, slot_id)
    configure_window(win)
    M.update_title(slot_id)
    M.restore_view(item)

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if item.win == win then
                M.save_view(item)
                item.win = nil
            end
        end,
    })

    local group = vim.api.nvim_create_augroup(AUGROUP_PREFIX .. slot_id, {
        clear = true,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            if state.valid_window(item.win) and vim.api.nvim_get_current_win() == item.win then
                item.buf = vim.api.nvim_get_current_buf()
                state.mark_buffer(item.buf, slot_id)
                M.update_title(slot_id)
            end
        end,
    })

    return win
end

return M
