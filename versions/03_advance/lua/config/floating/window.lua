local buffers = require("config.floating.buffers")
local state = require("config.floating.state")
local layout = require("config.floating.layout")

local M = {}
local title_for_buffer
local configure_window

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
    local title = state.label(slot_id)

    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " [" .. title .. "] ",
        title_pos = "center",
    }
end

function M.group_rect(item)
    local width, height = floating_size()
    local defaults = {
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
    }
    if not item or not item.geometry then return defaults end
    local geometry = item.geometry
    geometry.width = math.max(20, math.min(geometry.width or width, vim.o.columns - 4))
    geometry.height = math.max(4, math.min(geometry.height or height, vim.o.lines - 4))
    geometry.row = math.max(0, math.min(geometry.row or defaults.row, vim.o.lines - geometry.height - 2))
    geometry.col = math.max(0, math.min(geometry.col or defaults.col, vim.o.columns - geometry.width - 2))
    return vim.deepcopy(geometry)
end

local function pane_title(slot_id, pane_id, buf)
    local item = state.slot(slot_id)
    local suffix = item.panes and vim.tbl_count(item.panes) > 1 and ("[" .. pane_id .. "]") or ""
    return " [" .. state.label(slot_id) .. "]" .. suffix .. " " .. title_for_buffer(slot_id, buf):gsub("^ %[[^%]]+%] ", "")
end

local function pane_config(slot_id, pane_id, rect, buf)
    return {
        relative = "editor", width = rect.width, height = rect.height,
        row = rect.row, col = rect.col, style = "minimal", border = "single",
        title = pane_title(slot_id, pane_id, buf), title_pos = "center",
    }
end

function M.apply_layout(slot_id)
    local item = layout.ensure(state.slot(slot_id))
    local rects = layout.rectangles(item, M.group_rect(item))
    for pane_id, pane in pairs(item.panes) do
        if state.valid_window(pane.win) and rects[pane_id] then
            pcall(vim.api.nvim_win_set_config, pane.win, pane_config(slot_id, pane_id, rects[pane_id], vim.api.nvim_win_get_buf(pane.win)))
        end
    end
end

function M.open_pane(slot_id, pane_id, buf)
    local item = layout.ensure(state.slot(slot_id))
    local reopen_dashboard = vim.bo[buf].filetype == "alpha"
        and #state.visible_windows_for_buffer(buf) == 0
    local old_dashboard_buf
    if reopen_dashboard then
        old_dashboard_buf = buf
        buf = buffers.create_home(slot_id)
        pcall(vim.api.nvim_buf_delete, old_dashboard_buf, { force = true })
    end
    if vim.bo[buf].filetype == state.SLOT_FILETYPE then vim.bo[buf].bufhidden = "hide" end
    local rect = layout.rectangles(item, M.group_rect(item))[pane_id]
    local win = vim.api.nvim_open_win(buf, true, pane_config(slot_id, pane_id, rect, buf))
    local pane = item.panes[pane_id]
    pane.win, pane.buf = win, buf
    state.mark_pane(win, buf, slot_id, pane_id)
    configure_window(win)
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
            if state.valid_window(win) and vim.api.nvim_get_current_win() == win then
                pane.buf = vim.api.nvim_get_current_buf()
                state.mark_pane(win, pane.buf, slot_id, pane.id)
                if pane.id == "A" then item.buf, item.win = pane.buf, win end
                M.update_title(slot_id)
            end
        end,
    })
    if reopen_dashboard then
        pcall(vim.cmd, "DashboardHome")
        pane.buf = vim.api.nvim_win_get_buf(win)
        state.mark_pane(win, pane.buf, slot_id, pane.id)
        if pane.id == "A" then item.buf, item.win = pane.buf, win end
        M.update_title(slot_id)
    end
    return win
end

function M.open_transient(buf, title)
    local width, height = floating_size()

    return vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
    })
end

title_for_buffer = function(slot_id, buf)
    local name = "Dashboard"

    if state.valid_buffer(buf) then
        local path = vim.api.nvim_buf_get_name(buf)

        if vim.bo[buf].buftype == "terminal" then
            name = vim.fn.fnamemodify(vim.o.shell, ":t") .. " [Terminal]"
        elseif path ~= "" then
            name = vim.fn.fnamemodify(path, ":t")
        elseif vim.bo[buf].filetype ~= "alpha" and vim.bo[buf].filetype ~= state.SLOT_FILETYPE then
            name = "[No Name]"
        end
    end

    return " [" .. state.label(slot_id) .. "] " .. name .. " "
end

configure_window = function(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local plain_window = false

    if state.valid_buffer(buf) then
        local filetype = vim.bo[buf].filetype

        plain_window = vim.bo[buf].buftype == "terminal"
            or filetype == state.SLOT_FILETYPE
            or filetype == "alpha"
    end

    vim.wo[win].number = not plain_window
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = plain_window and "no" or "yes"
end

function M.update_title(slot_id)
    local item = state.slots[slot_id]

    if not item then
        return
    end

    if item.panes then
        for pane_id, pane in pairs(item.panes) do
            if state.valid_window(pane.win) then
                configure_window(pane.win)
                pcall(vim.api.nvim_win_set_config, pane.win, { title = pane_title(slot_id, pane_id, vim.api.nvim_win_get_buf(pane.win)), title_pos = "center" })
            end
        end
        return
    end
    if not state.valid_window(item.win) then return end

    configure_window(item.win)

    pcall(vim.api.nvim_win_set_config, item.win, {
        title = title_for_buffer(slot_id, vim.api.nvim_win_get_buf(item.win)),
        title_pos = "center",
    })
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

    if not item then
        return
    end

    if item.panes then
        for _, pane in pairs(item.panes) do
            -- Dashboard/scratch buffers often use bufhidden=wipe.  A group
            -- toggle is a hide operation, so keep those buffers alive until
            -- the whole floating slot is explicitly closed.
            if state.valid_buffer(pane.buf) then
                vim.bo[pane.buf].bufhidden = "hide"
            end
            if state.valid_window(pane.win) then pcall(vim.api.nvim_win_close, pane.win, true) end
            pane.win = nil
        end
        item.win = nil
        buffers.cleanup_empty()
        if state.valid_window(item.return_win) then
            pcall(vim.api.nvim_set_current_win, item.return_win)
        end
        return
    end
    if not state.valid_window(item.win) then return end

    M.save_view(item)
    pcall(vim.api.nvim_win_close, item.win, true)
    item.win = nil
    buffers.cleanup_empty()

    if state.valid_window(item.return_win) then
        pcall(vim.api.nvim_set_current_win, item.return_win)
    end
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
    if item.panes then
        local pane = item.panes.A
        pane.buf = buf
        local win = M.open_pane(slot_id, "A", buf)
        item.win, item.buf = win, buf
        return win
    end
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

vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("ConfigFloatingLayoutResize", { clear = true }),
    callback = function()
        for slot_id, item in pairs(state.slots) do
            if item.panes then M.apply_layout(slot_id) end
        end
    end,
})

return M
