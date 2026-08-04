local metadata_store = require("config.sessions.metadata")
local session_slots = require("config.sessions.slots")

local M = {}

local read_metadata = metadata_store.read
local write_metadata = metadata_store.write
local configured_slot_id = session_slots.configured
local known_slot_id = session_slots.known

local function confirmed(answer)
    return answer == "" or answer == "y" or answer == "Y"
end

local function valid_slot(slot)
    slot = known_slot_id(slot) or configured_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return nil
    end

    return slot
end

function M.edit_field(slot, field, label, opts)
    opts = opts or {}
    slot = valid_slot(slot)

    if slot == nil then
        return
    end

    local metadata = read_metadata(slot)
    local previous = metadata[field] or ""

    vim.ui.input({
        prompt = "Session " .. slot .. " " .. label .. ": ",
        default = previous,
    }, function(value)
        if value == nil then
            if opts.on_cancel then
                opts.on_cancel()
            end
            return
        end

        if value == previous then
            if opts.on_cancel then
                opts.on_cancel()
            end
            return
        end

        vim.ui.input({
            prompt = "Update session " .. slot .. " " .. label .. "? Press Enter or type y to confirm: ",
        }, function(answer)
            if not confirmed(answer) then
                if opts.on_cancel then
                    opts.on_cancel()
                end
                return
            end

            metadata = read_metadata(slot)
            metadata.slot = slot
            metadata[field] = value

            write_metadata(slot, metadata)
            vim.notify("Updated session " .. slot .. " " .. label)

            if opts.on_update then
                opts.on_update()
            end
        end)
    end)
end

local function split_lines(text)
    if text == "" then
        return {}
    end

    return vim.split(text, "\n", {
        plain = true,
    })
end

function M.open_editor(slot, opts)
    opts = opts or {}
    slot = valid_slot(slot)

    if slot == nil then
        return
    end

    local metadata = read_metadata(slot)
    local previous = metadata.note or ""
    local width = math.min(math.max(60, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
    local height = math.min(math.max(12, math.floor(vim.o.lines * 0.55)), vim.o.lines - 4)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
        title = " Session " .. slot .. " note ",
        title_pos = "center",
    })

    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].swapfile = false
    vim.wo[win].wrap = true

    local ok_cmp, cmp = pcall(require, "cmp")

    if ok_cmp then
        cmp.setup.buffer({
            enabled = false,
        })
    end

    local initial_lines = split_lines(previous)

    if #initial_lines == 0 then
        initial_lines = { "" }
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)

    local function current_note()
        return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end

    local function stop_insert_mode()
        if vim.fn.mode():match("^[iR]") then
            vim.cmd("stopinsert")
        end
    end

    local function close_editor()
        stop_insert_mode()

        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end

        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, {
                force = true,
            })
        end

        vim.schedule(function()
            stop_insert_mode()

            if opts.on_close then
                opts.on_close()
            end
        end)
    end

    local function cancel_editor()
        local next_note = current_note()

        if next_note == previous then
            close_editor()
            return
        end

        vim.ui.input({
            prompt = "Discard session " .. slot .. " note changes? Type y to confirm: ",
        }, function(answer)
            if answer == "y" or answer == "Y" then
                close_editor()
            else
                vim.schedule(function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_set_current_win(win)
                        vim.cmd("startinsert")
                    end
                end)
            end
        end)
    end

    local function save_editor()
        local next_note = current_note()

        if next_note == previous then
            close_editor()
            return
        end

        vim.ui.input({
            prompt = "Update session " .. slot .. " note? Press Enter or type y to confirm: ",
        }, function(answer)
            if not confirmed(answer) then
                return
            end

            metadata = read_metadata(slot)
            metadata.slot = slot
            metadata.note = next_note

            write_metadata(slot, metadata)
            if opts.notify ~= false then
                vim.notify("Updated session " .. slot .. " note")
            end
            close_editor()

            if opts.on_update then
                opts.on_update()
            end

            vim.schedule(function()
                stop_insert_mode()
            end)
        end)
    end

    vim.keymap.set({ "n", "i" }, "<Esc>", cancel_editor, {
        buffer = buf,
        silent = true,
        desc = "Cancel session note edit",
    })

    vim.keymap.set("n", "<CR>", save_editor, {
        buffer = buf,
        silent = true,
        desc = "Save session note",
    })

    vim.keymap.set({ "n", "i" }, "<C-s>", save_editor, {
        buffer = buf,
        silent = true,
        desc = "Save session note",
    })

    vim.cmd("startinsert")
end

return M
