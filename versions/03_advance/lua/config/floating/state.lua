local M = {}

M.SLOT_FILETYPE = "FloatingSlot"
M.slots = {}
M.SLOT_ORDER = {
    "`",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
}

local slot_rank = {}

for index, slot_id in ipairs(M.SLOT_ORDER) do
    slot_rank[slot_id] = index
end

function M.normalize_slot_id(slot_id)
    if slot_id == nil then
        return nil
    end

    return tostring(slot_id)
end

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
    slot_id = M.normalize_slot_id(slot_id)

    M.slots[slot_id] = M.slots[slot_id] or {
        buf = nil,
        win = nil,
        view = nil,
        cursor = nil,
        panes = nil,
        layout = nil,
        return_win = nil,
    }

    return M.slots[slot_id]
end

function M.slot_ids()
    return vim.deepcopy(M.SLOT_ORDER)
end

function M.mark_window(win, slot_id)
    slot_id = M.normalize_slot_id(slot_id)

    vim.w[win].floating_slot_id = slot_id
end

function M.mark_pane(win, buf, slot_id, pane_id)
    M.mark_window(win, slot_id)
    vim.w[win].floating_pane_id = pane_id
    M.mark_buffer(buf, slot_id)
    vim.b[buf].floating_pane_id = pane_id
end

function M.window_pane_id(win)
    win = win or vim.api.nvim_get_current_win()
    if not M.valid_window(win) then return nil end
    local ok, pane_id = pcall(vim.api.nvim_win_get_var, win, "floating_pane_id")
    return ok and pane_id or "A"
end

function M.mark_buffer(buf, slot_id)
    slot_id = M.normalize_slot_id(slot_id)

    vim.b[buf].floating_slot_id = slot_id
end

function M.clear_buffer_slot(buf, slot_id)
    slot_id = M.normalize_slot_id(slot_id)

    if M.valid_buffer(buf) and vim.b[buf].floating_slot_id == slot_id then
        vim.b[buf].floating_slot_id = nil
        vim.b[buf].floating_pane_id = nil
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
            if item.panes then
                for pane_id, pane in pairs(item.panes) do
                    if pane.buf == buf then
                        return M.label(slot_id) .. (vim.tbl_count(item.panes) > 1 and ("][" .. pane_id) or "")
                    end
                end
            end
            return M.label(slot_id)
        end
    end

    local slot_id = vim.b[buf].floating_slot_id

    if slot_id ~= nil then
        local pane_id = vim.b[buf].floating_pane_id
        local item = M.slots[M.normalize_slot_id(slot_id)]
        local multiple = item and item.panes and vim.tbl_count(item.panes) > 1
        return M.label(slot_id) .. (multiple and pane_id and ("][" .. pane_id) or "")
    end

    return nil
end

function M.assigned_slots_by_buffer()
    local assigned = {}

    for slot_id, item in pairs(M.slots) do
        if item.panes then
            local multiple = vim.tbl_count(item.panes) > 1
            for pane_id, pane in pairs(item.panes) do
                if M.valid_buffer(pane.buf) and vim.bo[pane.buf].filetype ~= M.SLOT_FILETYPE then
                    assigned[pane.buf] = assigned[pane.buf] or {}
                    table.insert(assigned[pane.buf], { slot = slot_id, label = M.label(slot_id) .. (multiple and ("][" .. pane_id) or ""), rank = M.slot_rank(slot_id) })
                end
            end
            goto continue
        end
        if M.valid_buffer(item.buf) and vim.bo[item.buf].filetype ~= M.SLOT_FILETYPE then
            assigned[item.buf] = assigned[item.buf] or {}
            table.insert(assigned[item.buf], {
                slot = slot_id,
                label = M.label(slot_id),
                rank = M.slot_rank(slot_id),
            })
        end
        ::continue::
    end

    for _, slots in pairs(assigned) do
        table.sort(slots, function(a, b)
            return a.rank < b.rank
        end)
    end

    return assigned
end

function M.has_assignment(buf)
    if not M.valid_buffer(buf) then
        return false
    end

    for _, item in pairs(M.slots) do
        if item.panes then
            for _, pane in pairs(item.panes) do
                if pane.buf == buf then return true end
            end
        end
        if item.buf == buf then
            return true
        end
    end

    local slot_id = M.normalize_slot_id(vim.b[buf].floating_slot_id)

    if slot_id ~= nil then
        local item = M.slots[slot_id]

        return item == nil or item.buf == nil or item.buf == buf
    end

    return false
end

function M.label(slot_id)
    slot_id = tostring(slot_id)

    if slot_id == "`" then
        return "F~"
    end

    return "F" .. slot_id
end

function M.slot_rank(slot_id)
    return slot_rank[tostring(slot_id)] or 1000
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

    return M.slot_rank(slot_id)
end

function M.current_slots()
    local entries = {}

    for slot_id, item in pairs(M.slots) do
        if item.panes then
            local panes = {}
            for pane_id, pane in pairs(item.panes) do
                local saved = { id = pane_id }
                if M.valid_buffer(pane.buf) then
                    local name = vim.api.nvim_buf_get_name(pane.buf)
                    if name ~= "" and vim.bo[pane.buf].buftype == "" then
                        saved.file = name
                    end
                end
                table.insert(panes, saved)
            end
            table.sort(panes, function(a, b) return a.id < b.id end)
            if #panes > 0 then
                table.insert(entries, {
                    slot = slot_id,
                    panes = panes,
                    layout = vim.deepcopy(item.layout),
                    geometry = vim.deepcopy(item.geometry),
                    visible = M.valid_window(item.win) == true,
                })
            end
            goto continue
        end
        if M.valid_buffer(item.buf) and vim.bo[item.buf].filetype ~= M.SLOT_FILETYPE then
            local name = vim.api.nvim_buf_get_name(item.buf)

            if name ~= "" and vim.bo[item.buf].buftype == "" then
                table.insert(entries, {
                    slot = slot_id,
                    file = name,
                    visible = M.valid_window(item.win) == true,
                })
            end
        end
        ::continue::
    end

    table.sort(entries, function(a, b)
        return M.slot_rank(a.slot) < M.slot_rank(b.slot)
    end)

    return entries
end

return M
