local M = {}

local SLOT_FILETYPE = "FloatingSlot"
local AUGROUP_PREFIX = "ConfigFloatingSlot"
local slots = {}

local function valid_buffer(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_window(win)
    return win and vim.api.nvim_win_is_valid(win)
end

local function visible_windows_for_buffer(buf)
    local windows = {}

    if not valid_buffer(buf) then
        return windows
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            table.insert(windows, win)
        end
    end

    return windows
end

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

    if valid_buffer(buf) then
        local path = vim.api.nvim_buf_get_name(buf)

        if path ~= "" then
            name = vim.fn.fnamemodify(path, ":t")
        elseif vim.bo[buf].filetype ~= "alpha" and vim.bo[buf].filetype ~= SLOT_FILETYPE then
            name = "[No Name]"
        end
    end

    return " [F" .. slot_id .. "] " .. name .. " "
end

local function update_title(slot_id)
    local item = slots[slot_id]

    if not item or not valid_window(item.win) then
        return
    end

    pcall(vim.api.nvim_win_set_config, item.win, {
        title = title_for_buffer(slot_id, vim.api.nvim_win_get_buf(item.win)),
        title_pos = "center",
    })
end

local function listed_empty_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.api.nvim_buf_get_name(buf) == ""
            and vim.bo[buf].buftype == ""
            and not vim.bo[buf].modified
            and vim.api.nvim_buf_line_count(buf) == 1
            and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
        then
            buffers[buf] = true
        end
    end

    return buffers
end

local function hidden_listed_empty_buffers()
    local buffers = {}

    for buf in pairs(listed_empty_buffers()) do
        if #visible_windows_for_buffer(buf) == 0 then
            buffers[buf] = true
        end
    end

    return buffers
end

local function cleanup_hidden_listed_empty_buffers()
    for buf in pairs(hidden_listed_empty_buffers()) do
        pcall(vim.api.nvim_buf_delete, buf, {
            force = true,
        })
    end
end

local function cleanup_new_listed_empty_buffers(before)
    for buf in pairs(listed_empty_buffers()) do
        if not before[buf] then
            pcall(vim.api.nvim_buf_delete, buf, {
                force = true,
            })
        end
    end
end

local function configure_window(win)
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "yes"
end

local function slot(slot_id)
    slots[slot_id] = slots[slot_id] or {
        buf = nil,
        win = nil,
        view = nil,
        cursor = nil,
    }

    return slots[slot_id]
end

local function save_view(item)
    if not valid_window(item.win) then
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

    if valid_window(current_win) and current_win ~= item.win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function hide_slot(slot_id)
    local item = slots[slot_id]

    if not item or not valid_window(item.win) then
        return
    end

    save_view(item)
    pcall(vim.api.nvim_win_close, item.win, true)
    item.win = nil
    cleanup_hidden_listed_empty_buffers()
end

local function hide_other_slots(active_slot_id)
    for slot_id in pairs(slots) do
        if slot_id ~= active_slot_id then
            hide_slot(slot_id)
        end
    end
end

local function restore_view(item)
    if not valid_window(item.win) then
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

        if valid_window(current_win) and current_win ~= item.win then
            pcall(vim.api.nvim_set_current_win, current_win)
        end
    end
end

local function mark_window(win, slot_id)
    vim.w[win].floating_slot_id = slot_id
end

local function mark_buffer(buf, slot_id)
    vim.b[buf].floating_slot_id = slot_id
end

local function clear_buffer_slot(buf, slot_id)
    if valid_buffer(buf) and vim.b[buf].floating_slot_id == slot_id then
        vim.b[buf].floating_slot_id = nil
    end
end

local function create_home_buffer(slot_id)
    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buflisted = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = SLOT_FILETYPE
    mark_buffer(buf, slot_id)

    return buf
end

local function open_window(slot_id, buf)
    local item = slot(slot_id)
    local win = vim.api.nvim_open_win(buf, true, floating_config(slot_id))

    item.win = win
    item.buf = buf
    mark_window(win, slot_id)
    mark_buffer(buf, slot_id)
    configure_window(win)
    update_title(slot_id)
    restore_view(item)

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if item.win == win then
                save_view(item)
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
            if valid_window(item.win) and vim.api.nvim_get_current_win() == item.win then
                item.buf = vim.api.nvim_get_current_buf()
                mark_buffer(item.buf, slot_id)
                update_title(slot_id)
            end
        end,
    })

    return win
end

local function show_home(slot_id)
    local item = slot(slot_id)
    local buf = create_home_buffer(slot_id)
    local listed_empty_before = listed_empty_buffers()

    item.buf = buf

    if valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        open_window(slot_id, buf)
    end

    pcall(vim.cmd, "DashboardHome")

    local current = vim.api.nvim_get_current_buf()

    if valid_buffer(buf) and buf ~= current then
        pcall(vim.api.nvim_buf_delete, buf, {
            force = true,
        })
    end

    vim.bo[current].buflisted = false
    item.buf = current
    mark_buffer(current, slot_id)
    cleanup_new_listed_empty_buffers(listed_empty_before)
    cleanup_hidden_listed_empty_buffers()
    update_title(slot_id)
end

local function safe_delete_old_buffer(buf, force)
    if not valid_buffer(buf) then
        return
    end

    if #visible_windows_for_buffer(buf) ~= 0 then
        return
    end

    local filetype = vim.bo[buf].filetype

    if
        filetype == "alpha"
        or filetype == SLOT_FILETYPE
        or filetype == "NvimTree"
        or filetype == "notify"
    then
        return
    end

    if vim.bo[buf].buftype ~= "" then
        return
    end

    if vim.bo[buf].modified and not force then
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

        vim.notify("Buffer has unsaved changes: " .. name, vim.log.levels.WARN)
        return
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
        force = force,
    })

    if not ok then
        vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
    end
end

function M.is_slot_window(win)
    win = win or vim.api.nvim_get_current_win()

    if not valid_window(win) then
        return false
    end

    local ok, slot_id = pcall(vim.api.nvim_win_get_var, win, "floating_slot_id")

    return ok and slot_id ~= nil
end

function M.window_slot_id(win)
    win = win or vim.api.nvim_get_current_win()

    if not valid_window(win) then
        return nil
    end

    local ok, slot_id = pcall(vim.api.nvim_win_get_var, win, "floating_slot_id")

    if ok then
        return slot_id
    end

    return nil
end

function M.is_slot_buffer(buf)
    if not valid_buffer(buf) then
        return false
    end

    return vim.b[buf].floating_slot_id ~= nil or vim.bo[buf].filetype == SLOT_FILETYPE
end

function M.slot_label_for_buffer(buf)
    if not valid_buffer(buf) then
        return nil
    end

    for slot_id, item in pairs(slots) do
        if item.buf == buf then
            return "F" .. slot_id
        end
    end

    local slot_id = vim.b[buf].floating_slot_id

    if slot_id ~= nil then
        return "F" .. slot_id
    end

    return nil
end

function M.slot_display_name(buf)
    if not valid_buffer(buf) or not M.slot_label_for_buffer(buf) then
        return nil
    end

    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":t")
end

function M.slot_sort_rank(buf)
    if not valid_buffer(buf) then
        return nil
    end

    local slot_id

    for candidate_id, item in pairs(slots) do
        if item.buf == buf then
            slot_id = candidate_id
            break
        end
    end

    slot_id = slot_id or vim.b[buf].floating_slot_id

    if slot_id == nil then
        return nil
    end

    if slot_id == 0 then
        return 10
    end

    return slot_id
end

function M.current_slots()
    local entries = {}

    for slot_id, item in pairs(slots) do
        if valid_buffer(item.buf) then
            local name = vim.api.nvim_buf_get_name(item.buf)

            if name ~= "" and vim.bo[item.buf].buftype == "" then
                table.insert(entries, {
                    slot = slot_id,
                    file = name,
                    visible = valid_window(item.win),
                })
            end
        end
    end

    table.sort(entries, function(a, b)
        local a_slot = tonumber(a.slot) or 0
        local b_slot = tonumber(b.slot) or 0

        if a_slot == 0 then
            a_slot = 10
        end

        if b_slot == 0 then
            b_slot = 10
        end

        return a_slot < b_slot
    end)

    return entries
end

function M.restore_slot(slot_id, file, opts)
    opts = opts or {}

    if type(file) ~= "string" or file == "" or vim.fn.filereadable(file) == 0 then
        return false
    end

    local buf = vim.fn.bufadd(file)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true

    local item = slot(slot_id)

    item.buf = buf
    mark_buffer(buf, slot_id)

    if opts.visible then
        M.open_buffer(buf, {
            slot_id = slot_id,
        })
    end

    return true
end

function M.show_buffer_slot(buf)
    if not valid_buffer(buf) then
        return false
    end

    for slot_id, item in pairs(slots) do
        if item.buf == buf then
            hide_other_slots(slot_id)

            local ok_terminal, terminal = pcall(require, "config.terminal")

            if ok_terminal then
                terminal.hide_float_terminal_if_visible()
            end

            if valid_window(item.win) then
                vim.api.nvim_set_current_win(item.win)
            else
                open_window(slot_id, buf)
            end

            return true
        end
    end

    local slot_id = vim.b[buf].floating_slot_id

    if slot_id == nil then
        return false
    end

    local item = slot(slot_id)

    item.buf = buf
    hide_other_slots(slot_id)

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal then
        terminal.hide_float_terminal_if_visible()
    end

    if valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        open_window(slot_id, buf)
    end

    update_title(slot_id)

    return true
end

function M.toggle(slot_id)
    local item = slot(slot_id)

    if valid_window(item.win) then
        hide_slot(slot_id)
        return
    end

    hide_other_slots(slot_id)

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal then
        terminal.hide_float_terminal_if_visible()
    end

    if valid_buffer(item.buf) then
        open_window(slot_id, item.buf)
        return
    end

    show_home(slot_id)
end

function M.open_buffer(buf, opts)
    opts = opts or {}

    if not valid_buffer(buf) then
        return false
    end

    local slot_id = opts.slot_id or M.window_slot_id()

    if slot_id == nil then
        return false
    end

    local item = slot(slot_id)

    hide_other_slots(slot_id)

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal then
        terminal.hide_float_terminal_if_visible()
    end

    if not valid_window(item.win) then
        open_window(slot_id, valid_buffer(item.buf) and item.buf or create_home_buffer(slot_id))
    end

    local old_buf = vim.api.nvim_win_get_buf(item.win)

    vim.api.nvim_win_set_buf(item.win, buf)
    item.buf = buf
    mark_buffer(buf, slot_id)
    vim.api.nvim_set_current_win(item.win)
    update_title(slot_id)

    if old_buf ~= buf then
        clear_buffer_slot(old_buf, slot_id)
        safe_delete_old_buffer(old_buf, opts.force)
    end

    cleanup_hidden_listed_empty_buffers()

    return true
end

function M.open_file(path, opts)
    if not path or path == "" then
        return false
    end

    local buf = vim.fn.bufadd(path)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true

    return M.open_buffer(buf, opts)
end

function M.close_current(force)
    local win = vim.api.nvim_get_current_win()
    local slot_id = M.window_slot_id(win)

    if slot_id == nil then
        return false
    end

    local item = slot(slot_id)
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].filetype == "alpha" or vim.bo[buf].filetype == SLOT_FILETYPE then
        pcall(vim.api.nvim_win_close, win, true)
        item.win = nil
        return true
    end

    if vim.bo[buf].modified and not force then
        vim.notify("Buffer has unsaved changes. Use Space Q to force.", vim.log.levels.WARN)
        return true
    end

    show_home(slot_id)
    clear_buffer_slot(buf, slot_id)

    if #visible_windows_for_buffer(buf) == 0 and valid_buffer(buf) then
        local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
            force = force,
        })

        if not ok then
            vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
        end
    end

    return true
end

function M.reject_window_action()
    if M.is_slot_window() then
        vim.notify("Floating slots are separate from window splits and moves.", vim.log.levels.INFO)
        return true
    end

    return false
end

function M.hide_all()
    for slot_id in pairs(slots) do
        hide_slot(slot_id)
    end
end

return M
