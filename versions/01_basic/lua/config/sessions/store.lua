local metadata_store = require("config.sessions.metadata")
local session_buffers = require("config.sessions.buffers")
local session_paths = require("config.sessions.paths")
local session_layout = require("config.sessions.layout")
local session_restore = require("config.sessions.restore")
local session_slots = require("config.sessions.slots")

local M = {}

local current_files = session_buffers.current_files
local current_floating_slots = session_restore.current_floating_slots
local current_terminal_windows = session_restore.current_terminal_windows
local current_tree_state = session_restore.current_tree_state
local read_metadata = metadata_store.read
local write_metadata = metadata_store.write

local function confirmed(answer)
    return answer == "" or answer == "y" or answer == "Y"
end

function M.exists(slot)
    return vim.fn.filereadable(session_paths.metadata_path(slot)) == 1
end

local function move_file(from, to)
    if vim.fn.filereadable(from) == 0 then
        return true
    end

    local ok = vim.fn.rename(from, to) == 0

    if not ok then
        vim.notify("Failed to move " .. from .. " to " .. to, vim.log.levels.ERROR)
    end

    return ok
end

local function update_metadata_slot(slot)
    local metadata = read_metadata(slot)

    if vim.tbl_isempty(metadata) then
        return
    end

    metadata.slot = slot
    write_metadata(slot, metadata)
end

local function hidden_floating_slots()
    local slots = current_floating_slots()

    for _, item in ipairs(slots) do
        item.visible = false
    end

    return slots
end

local function hide_floating_slots()
    local ok, floating = pcall(require, "config.floating")

    if ok and type(floating.hide_all) == "function" then
        pcall(floating.hide_all)
    end
end

function M.save(slot, force, opts)
    opts = opts or {}
    slot = session_slots.configured(slot)

    if slot == nil then
        vim.notify(session_slots.configured_message(), vim.log.levels.ERROR)
        if opts.on_cancel then
            opts.on_cancel()
        end
        return
    end

    if M.exists(slot) and not force then
        vim.ui.input({
            prompt = "Overwrite session " .. slot .. "? Press Enter or type y to confirm: ",
        }, function(answer)
            if confirmed(answer) then
                M.save(slot, true, opts)
            elseif opts.on_cancel then
                opts.on_cancel()
            end
        end)

        return
    end

    if opts.before_write then
        opts.before_write()
    end

    vim.fn.mkdir(session_paths.dir, "p")

    hide_floating_slots()

    local ok, layout = pcall(session_layout.snapshot)

    if not ok then
        vim.notify("Failed to save session " .. slot .. ": " .. layout, vim.log.levels.ERROR)
        if opts.on_cancel then
            opts.on_cancel()
        end
        return
    end

    local metadata = read_metadata(slot)

    metadata.slot = slot
    metadata.cwd = vim.fn.getcwd()
    metadata.files = current_files()
    metadata.terminals = current_terminal_windows()
    metadata.floating_slots = hidden_floating_slots()
    metadata.tree = current_tree_state()
    metadata.layout = layout
    metadata.saved_at = os.date("%Y-%m-%d %H:%M:%S")

    write_metadata(slot, metadata)
    pcall(vim.fn.delete, session_paths.session_path(slot))

    if opts.notify ~= false then
        vim.notify("Saved session " .. slot)
    end

    if opts.on_update then
        opts.on_update()
    end
end

function M.move(from_slot, to_slot, opts)
    opts = opts or {}
    from_slot = session_slots.known(from_slot)
    to_slot = session_slots.configured(to_slot)

    if from_slot == nil then
        vim.notify("Source session slot is not known.", vim.log.levels.ERROR)
        return false
    end

    if to_slot == nil then
        vim.notify(session_slots.configured_message(), vim.log.levels.ERROR)
        return false
    end

    if from_slot == to_slot then
        vim.notify("Session is already in slot " .. from_slot, vim.log.levels.INFO)
        return false
    end

    if not M.exists(from_slot) then
        vim.notify("Session " .. from_slot .. " is empty.", vim.log.levels.WARN)
        return false
    end

    vim.fn.mkdir(session_paths.dir, "p")

    local tmp_base = session_paths.dir
        .. "/slot-swap-"
        .. from_slot
        .. "-"
        .. to_slot
        .. "-"
        .. vim.fn.localtime()
    local from_files = session_paths.slot_files(from_slot)
    local to_files = session_paths.slot_files(to_slot)
    local tmp_files = {
        tmp_base .. ".vim",
        tmp_base .. ".json",
    }
    local to_exists = M.exists(to_slot)

    for index, path in ipairs(from_files) do
        if not move_file(path, tmp_files[index]) then
            return false
        end
    end

    if to_exists then
        for index, path in ipairs(to_files) do
            if not move_file(path, from_files[index]) then
                return false
            end
        end
    end

    for index, path in ipairs(tmp_files) do
        if not move_file(path, to_files[index]) then
            return false
        end
    end

    update_metadata_slot(from_slot)
    update_metadata_slot(to_slot)

    if to_exists then
        vim.notify("Swapped sessions " .. from_slot .. " and " .. to_slot)
    else
        vim.notify("Moved session " .. from_slot .. " to " .. to_slot)
    end

    if opts.on_update then
        opts.on_update(to_slot)
    end

    return true, to_slot, {
        from_slot = from_slot,
        to_exists = to_exists,
    }
end

function M.delete(slot, force, opts)
    opts = opts or {}
    slot = session_slots.known(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    if not force then
        vim.ui.input({
            prompt = "Delete session " .. slot .. "? Press Enter or type y to confirm: ",
        }, function(answer)
            if confirmed(answer) then
                M.delete(slot, true, opts)
            elseif opts.on_cancel then
                opts.on_cancel()
            end
        end)

        return
    end

    local removed = false
    local session_path = session_paths.session_path(slot)
    local metadata_path = session_paths.metadata_path(slot)

    if vim.fn.filereadable(session_path) == 1 then
        vim.fn.delete(session_path)
        removed = true
    end

    if vim.fn.filereadable(metadata_path) == 1 then
        vim.fn.delete(metadata_path)
        removed = true
    end

    if removed then
        vim.notify("Deleted session " .. slot)

        if opts.on_deleted then
            opts.on_deleted(slot)
        end

        if opts.on_update then
            opts.on_update()
        end
    else
        vim.notify("Session " .. slot .. " is already empty.", vim.log.levels.WARN)

        if opts.on_cancel then
            opts.on_cancel()
        end
    end
end

return M
