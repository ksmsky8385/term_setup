local buffers = require("config.floating.buffers")
local state = require("config.floating.state")
local window = require("config.floating.window")
local layout = require("config.floating.layout")

local M = {}

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function show_home(slot_id)
    local item = state.slot(slot_id)
    local buf = buffers.create_home(slot_id)
    local listed_empty_before = buffers.listed_empty()

    item.buf = buf

    if state.valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        window.open(slot_id, buf)
    end

    pcall(vim.cmd, "DashboardHome")

    local current = vim.api.nvim_get_current_buf()

    if state.valid_buffer(buf) and buf ~= current then
        pcall(vim.api.nvim_buf_delete, buf, {
            force = true,
        })
    end

    vim.bo[current].buflisted = false
    item.buf = current
    state.mark_buffer(current, slot_id)
    buffers.cleanup_new_listed_empty(listed_empty_before)
    buffers.cleanup_empty()
    window.update_title(slot_id)
end

function M.is_slot_window(win)
    return state.is_slot_window(win)
end

function M.window_slot_id(win)
    return state.window_slot_id(win)
end

function M.window_pane_id(win)
    return state.window_pane_id(win)
end

function M.window_label(win)
    local slot_id = state.window_slot_id(win)
    if not slot_id then return nil end
    local item = state.slot(slot_id)
    local multiple = item.panes and vim.tbl_count(item.panes) > 1
    return state.label(slot_id) .. (multiple and ("][" .. state.window_pane_id(win)) or "")
end

function M.slot_label(slot_id)
    return state.label(slot_id)
end

function M.is_slot_buffer(buf)
    return state.is_slot_buffer(buf)
end

function M.slot_label_for_buffer(buf)
    return state.slot_label_for_buffer(buf)
end

function M.assigned_slots_by_buffer()
    return state.assigned_slots_by_buffer()
end

function M.has_assignment(buf)
    return state.has_assignment(buf)
end

function M.clear_hidden_assignments_for_buffer(buf, keep_slot_id)
    keep_slot_id = state.normalize_slot_id(keep_slot_id)

    if not state.valid_buffer(buf) then
        return
    end

    for slot_id, item in pairs(state.slots) do
        if
            slot_id ~= keep_slot_id
            and item.buf == buf
            and not state.valid_window(item.win)
        then
            item.buf = nil
            item.view = nil
            item.cursor = nil
            state.clear_buffer_slot(buf, slot_id)
        end
    end
end

function M.slot_sort_rank(buf)
    return state.slot_sort_rank(buf)
end

function M.current_slots()
    return state.current_slots()
end

function M.slot_ids()
    return state.slot_ids()
end

function M.restore_slot(slot_id, file, opts)
    opts = opts or {}
    slot_id = state.normalize_slot_id(slot_id)

    if type(file) ~= "string" or file == "" or vim.fn.filereadable(file) == 0 then
        return false
    end

    local buf = vim.fn.bufadd(file)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true

    local item = state.slot(slot_id)

    item.buf = buf
    state.mark_buffer(buf, slot_id)

    if opts.visible then
        M.open_buffer(buf, {
            slot_id = slot_id,
        })
    end

    return true
end

function M.restore_group(saved)
    if type(saved) ~= "table" or type(saved.panes) ~= "table" then return false end
    local slot_id = state.normalize_slot_id(saved.slot)
    local item = state.slot(slot_id)
    item.panes, item.layout, item.geometry = {}, vim.deepcopy(saved.layout), vim.deepcopy(saved.geometry)
    for _, saved_pane in ipairs(saved.panes) do
        if type(saved_pane.id) == "string" then
            local buf
            if type(saved_pane.file) == "string" and vim.fn.filereadable(saved_pane.file) == 1 then
                buf = vim.fn.bufadd(saved_pane.file)
                vim.fn.bufload(buf)
                vim.bo[buf].buflisted = true
            else
                buf = buffers.create_home(slot_id)
            end
            item.panes[saved_pane.id] = { id = saved_pane.id, buf = buf, win = nil }
            state.mark_buffer(buf, slot_id)
            vim.b[buf].floating_pane_id = saved_pane.id
        end
    end
    if not next(item.panes) then item.panes, item.layout = nil, nil; return false end
    local representative_id = item.panes.A and "A" or next(item.panes)
    item.buf, item.win = item.panes[representative_id].buf, nil
    if saved.visible then M.open_slot(slot_id) end
    return true
end

function M.open_slot(slot_id)
    slot_id = state.normalize_slot_id(slot_id)
    local item = state.slot(slot_id)
    local current_win = vim.api.nvim_get_current_win()
    local current_slot = state.window_slot_id(current_win)

    if current_slot == nil then
        item.return_win = current_win
    elseif tostring(current_slot) ~= slot_id then
        local previous_item = state.slots[state.normalize_slot_id(current_slot)]
        if previous_item and state.valid_window(previous_item.return_win) then
            item.return_win = previous_item.return_win
        end
    end

    window.hide_other_slots(slot_id)

    if item.panes then
        local representative_id = item.panes.A and "A" or next(item.panes)
        local representative = representative_id and item.panes[representative_id] or nil

        -- A group may still be visible even when pane A was removed.  Do not
        -- create duplicate floats merely because the legacy representative
        -- item.win is nil or stale.
        if representative and state.valid_window(representative.win) then
            item.buf, item.win = representative.buf, representative.win
            vim.api.nvim_set_current_win(representative.win)
            return representative.win
        end

        local focus_win
        for pane_id, pane in pairs(item.panes) do
            if not state.valid_buffer(pane.buf) then
                pane.buf = buffers.create_home(slot_id)
                vim.bo[pane.buf].bufhidden = "hide"
                state.mark_buffer(pane.buf, slot_id)
                vim.b[pane.buf].floating_pane_id = pane_id
            end
            if state.valid_buffer(pane.buf) then
                if state.valid_window(pane.win) then
                    focus_win = focus_win or pane.win
                else
                    focus_win = window.open_pane(slot_id, pane_id, pane.buf)
                end
            end
        end
        window.apply_layout(slot_id)
        representative = representative_id and item.panes[representative_id] or nil
        item.buf = representative and representative.buf or nil
        item.win = representative and representative.win or focus_win
        if item.win and state.valid_window(item.win) then vim.api.nvim_set_current_win(item.win) end
        return item.win
    end

    if state.valid_window(item.win) then
        vim.api.nvim_set_current_win(item.win)
        return item.win
    end

    if state.valid_buffer(item.buf) then
        return window.open(slot_id, item.buf)
    end

    show_home(slot_id)
    buffers.cleanup_empty()

    return item.win
end

function M.show_buffer_slot(buf)
    if not state.valid_buffer(buf) then
        return false
    end

    for slot_id, item in pairs(state.slots) do
        if item.panes then
            for pane_id, pane in pairs(item.panes) do
                if pane.buf == buf then
                    window.hide_other_slots(slot_id)
                    if not state.valid_window(pane.win) then M.open_slot(slot_id) end
                    if state.valid_window(item.panes[pane_id].win) then vim.api.nvim_set_current_win(item.panes[pane_id].win) end
                    buffers.cleanup_empty()
                    return true
                end
            end
        end
        if item.buf == buf then
            window.hide_other_slots(slot_id)

            if state.valid_window(item.win) then
                vim.api.nvim_set_current_win(item.win)
            else
                window.open(slot_id, buf)
            end

            buffers.cleanup_empty()
            return true
        end
    end

    local slot_id = vim.b[buf].floating_slot_id

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)

    if item.panes then
        local pane_id = vim.b[buf].floating_pane_id
        local pane = pane_id and item.panes[pane_id] or nil
        if pane then
            pane.buf = buf
            window.hide_other_slots(slot_id)
            if not state.valid_window(pane.win) then M.open_slot(slot_id) end
            vim.api.nvim_set_current_win(pane.win)
            return true
        end
    end

    item.buf = buf
    window.hide_other_slots(slot_id)

    if state.valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        window.open(slot_id, buf)
    end

    window.update_title(slot_id)
    buffers.cleanup_empty()

    return true
end

function M.toggle(slot_id)
    slot_id = state.normalize_slot_id(slot_id)
    local item = state.slot(slot_id)

    local visible = state.valid_window(item.win)
    if item.panes then
        for _, pane in pairs(item.panes) do
            if state.valid_window(pane.win) then visible = true; break end
        end
    end

    if visible then
        window.hide_slot(slot_id)
        return
    end

    M.open_slot(slot_id)
end

function M.open_buffer(buf, opts)
    opts = opts or {}

    if not state.valid_buffer(buf) then
        return false
    end

    local slot_id = state.normalize_slot_id(opts.slot_id or M.window_slot_id())

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)
    local current_win = vim.api.nvim_get_current_win()
    if item.panes and M.window_slot_id(current_win) == slot_id then
        return M.set_window_buffer(current_win, buf)
    end

    if item.panes then
        M.open_slot(slot_id)
        return M.set_window_buffer(item.win, buf)
    end

    window.hide_other_slots(slot_id)

    if not state.valid_window(item.win) then
        window.open(slot_id, state.valid_buffer(item.buf) and item.buf or buffers.create_home(slot_id))
    end

    local old_buf = vim.api.nvim_win_get_buf(item.win)

    vim.api.nvim_win_set_buf(item.win, buf)
    item.buf = buf
    state.mark_buffer(buf, slot_id)
    vim.api.nvim_set_current_win(item.win)
    window.update_title(slot_id)

    if old_buf ~= buf then
        state.clear_buffer_slot(old_buf, slot_id)
        buffers.safe_delete_old(old_buf, opts.force)
    end

    buffers.cleanup_empty()

    return true
end

function M.set_window_buffer(win, buf)
    if not state.valid_window(win) or not state.valid_buffer(buf) then
        return false
    end

    local slot_id = M.window_slot_id(win)

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)
    layout.ensure(item)
    local pane_id = state.window_pane_id(win)
    local pane = item.panes[pane_id]
    local old_buf = vim.api.nvim_win_get_buf(win)

    vim.api.nvim_win_set_buf(win, buf)
    pane.win, pane.buf = win, buf
    if pane_id == "A" then item.win, item.buf = win, buf end
    state.mark_pane(win, buf, slot_id, pane_id)
    vim.api.nvim_set_current_win(win)
    window.update_title(slot_id)

    if old_buf ~= buf then
        state.clear_buffer_slot(old_buf, slot_id)
        buffers.cleanup_empty()
    end

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
    local slot_id = state.normalize_slot_id(M.window_slot_id(win))

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)
    layout.ensure(item)
    local pane_id = state.window_pane_id(win)
    local pane = item.panes[pane_id]
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) and not force then
        vim.notify("Terminal process is still running. Use Space Q to force.", vim.log.levels.WARN)
        return true
    end

    if vim.bo[buf].modified and not force then
        vim.notify("Buffer has unsaved changes. Use Space Q to force.", vim.log.levels.WARN)
        return true
    end

    state.clear_buffer_slot(buf, slot_id)

    local pane_count = vim.tbl_count(item.panes)
    if pane_count > 1 then
        if state.valid_window(win) then pcall(vim.api.nvim_win_close, win, true) end
        item.panes[pane_id] = nil
        layout.remove(item, pane_id)
        layout.compact(item)
        for compact_id, compact_pane in pairs(item.panes) do
            if state.valid_buffer(compact_pane.buf) then
                state.mark_buffer(compact_pane.buf, slot_id)
                vim.b[compact_pane.buf].floating_pane_id = compact_id
            end
            if state.valid_window(compact_pane.win) then
                state.mark_pane(compact_pane.win, compact_pane.buf, slot_id, compact_id)
            end
        end
        window.apply_layout(slot_id)
        window.update_title(slot_id)
        local remaining = item.panes.A
        item.buf, item.win = remaining and remaining.buf or nil, remaining and remaining.win or nil
        if remaining and state.valid_window(remaining.win) then vim.api.nvim_set_current_win(remaining.win) end
        if #state.visible_windows_for_buffer(buf) == 0 and state.valid_buffer(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = force })
        end
        buffers.cleanup_empty()
        return true
    end

    item.buf = nil
    item.panes = nil
    item.layout = nil
    item.geometry = nil

    if state.valid_window(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end

    item.win = nil
    item.view = nil
    item.cursor = nil

    if #state.visible_windows_for_buffer(buf) == 0 and state.valid_buffer(buf) then
        local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
            force = force,
        })

        if not ok then
            vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
        end
    end

    buffers.cleanup_empty()

    return true
end

local function next_pane_id(item)
    for code = string.byte("B"), string.byte("Z") do
        local id = string.char(code)
        if not item.panes[id] then return id end
    end
end

function M.split(direction)
    local win = vim.api.nvim_get_current_win()
    local slot_id = M.window_slot_id(win)
    if not slot_id then return false end
    local item = layout.ensure(state.slot(slot_id))
    local pane_id = state.window_pane_id(win)
    if not layout.can_split(item, pane_id, direction, window.group_rect(item)) then
        vim.notify("Not enough room for another floating split.", vim.log.levels.WARN)
        return true
    end
    local new_id = next_pane_id(item)
    if not new_id then vim.notify("Floating split limit reached.", vim.log.levels.WARN); return true end
    local buf = buffers.create_home(slot_id)
    item.panes[new_id] = { id = new_id, buf = buf, win = nil }
    layout.split(item, pane_id, direction, new_id)
    window.apply_layout(slot_id)
    local new_win = window.open_pane(slot_id, new_id, buf)
    window.apply_layout(slot_id)
    return true, new_win
end

function M.focus(direction)
    local win = vim.api.nvim_get_current_win()
    local slot_id = M.window_slot_id(win)
    if not slot_id then return false end
    local item = layout.ensure(state.slot(slot_id))
    if vim.tbl_count(item.panes) == 1 then
        local rect = window.group_rect(item)
        item.geometry = rect
        if direction == "left" then item.geometry.col = item.geometry.col - 1
        elseif direction == "right" then item.geometry.col = item.geometry.col + 1
        elseif direction == "up" then item.geometry.row = item.geometry.row - 1
        else item.geometry.row = item.geometry.row + 1 end
        window.apply_layout(slot_id)
        return true
    end
    local target = layout.neighbor(item, state.window_pane_id(win), direction, window.group_rect(item))
    if target and state.valid_window(item.panes[target].win) then vim.api.nvim_set_current_win(item.panes[target].win) end
    return true
end

function M.resize(direction, delta)
    local win = vim.api.nvim_get_current_win()
    local slot_id = M.window_slot_id(win)
    if not slot_id then return false end
    local item = layout.ensure(state.slot(slot_id))
    if vim.tbl_count(item.panes) == 1 then
        item.geometry = window.group_rect(item)
        if direction == "left" or direction == "right" then
            item.geometry.width = item.geometry.width + delta
        else
            item.geometry.height = item.geometry.height + delta
        end
        window.apply_layout(slot_id)
        return true
    end
    if layout.resize(item, state.window_pane_id(win), direction, delta, window.group_rect(item)) then window.apply_layout(slot_id) end
    return true
end

function M.reset_layout()
    local slot_id = M.window_slot_id()
    if not slot_id then return false end
    local item = layout.ensure(state.slot(slot_id))
    item.geometry = nil
    local function reset_ratios(node)
        if not node or node.pane then return end
        node.ratio = 0.5
        reset_ratios(node.first)
        reset_ratios(node.second)
    end
    reset_ratios(item.layout)
    window.apply_layout(slot_id)
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
    for slot_id in pairs(state.slots) do
        window.hide_slot(slot_id)
    end
end

return M
