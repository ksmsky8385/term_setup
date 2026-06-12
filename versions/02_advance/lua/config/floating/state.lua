local M = {}

M.SLOT_FILETYPE = "FloatingSlot"
M.slots = {}

function M.valid_buffer(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end

function M.valid_window(win)
    return win and vim.api.nvim_win_is_valid(win)
end

function M.visible_windows_for_buffer(buf)
    local windows = {}

    if not M.valid_buffer(buf) then
        return windows
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            table.insert(windows, win)
        end
    end

    return windows
end

function M.slot(slot_id)
    M.slots[slot_id] = M.slots[slot_id] or {
        buf = nil,
        win = nil,
        view = nil,
        cursor = nil,
    }

    return M.slots[slot_id]
end

function M.mark_window(win, slot_id)
    vim.w[win].floating_slot_id = slot_id
end

function M.mark_buffer(buf, slot_id)
    vim.b[buf].floating_slot_id = slot_id
end

function M.clear_buffer_slot(buf, slot_id)
    if M.valid_buffer(buf) and vim.b[buf].floating_slot_id == slot_id then
        vim.b[buf].floating_slot_id = nil
    end
end

function M.window_slot_id(win)
    win = win or vim.api.nvim_get_current_win()

    if not M.valid_window(win) then
        return nil
    end

    local ok, slot_id = pcall(vim.api.nvim_win_get_var, win, "floating_slot_id")

    if ok then
        return slot_id
    end

    return nil
end

function M.is_slot_window(win)
    return M.window_slot_id(win) ~= nil
end

function M.is_slot_buffer(buf)
    if not M.valid_buffer(buf) then
        return false
    end

    return vim.b[buf].floating_slot_id ~= nil or vim.bo[buf].filetype == M.SLOT_FILETYPE
end

function M.slot_label_for_buffer(buf)
    if not M.valid_buffer(buf) then
        return nil
    end

    for slot_id, item in pairs(M.slots) do
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

function M.slot_sort_rank(buf)
    if not M.valid_buffer(buf) then
        return nil
    end

    local slot_id

    for candidate_id, item in pairs(M.slots) do
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

    for slot_id, item in pairs(M.slots) do
        if M.valid_buffer(item.buf) then
            local name = vim.api.nvim_buf_get_name(item.buf)

            if name ~= "" and vim.bo[item.buf].buftype == "" then
                table.insert(entries, {
                    slot = slot_id,
                    file = name,
                    visible = M.valid_window(item.win),
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

return M
