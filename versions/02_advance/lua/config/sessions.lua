local M = {}

local metadata_store = require("config.sessions.metadata")
local session_note = require("config.sessions.note")
local session_buffers = require("config.sessions.buffers")
local session_picker = require("config.sessions.picker")
local session_paths = require("config.sessions.paths")
local session_restore = require("config.sessions.restore")
local session_slots = require("config.sessions.slots")
local session_store = require("config.sessions.store")

local session_path = session_paths.session_path
local known_slot_id = session_slots.known
local prepare_session_load = session_buffers.prepare_load
local read_metadata = metadata_store.read
local active_session_slot = nil

function M.configured_slot_ids()
    return session_slots.configured_ids()
end

function M.save(slot, force, opts)
    return session_store.save(slot, force, opts)
end

function M.move(from_slot, to_slot, opts)
    local ok, next_slot, state = session_store.move(from_slot, to_slot, opts)

    if ok and state then
        if active_session_slot == state.from_slot then
            active_session_slot = next_slot
        elseif state.to_exists and active_session_slot == next_slot then
            active_session_slot = state.from_slot
        end
    end

    return ok, next_slot
end

local function load_session(slot, path)
    local metadata = read_metadata(slot)
    local cwd = metadata.cwd
    local workspace = vim.fn.getcwd()

    if type(cwd) == "string" and cwd ~= "" then
        if vim.fn.isdirectory(cwd) == 1 then
            pcall(vim.cmd, "cd " .. vim.fn.fnameescape(cwd))
            workspace = vim.fn.getcwd()
        else
            vim.notify(
                "Session workspace is missing: " .. cwd .. ". Using current workspace: " .. workspace,
                vim.log.levels.WARN
            )
        end
    end

    vim.g.current_workspace_root = workspace

    local ok, err = pcall(function()
        vim.cmd("source " .. vim.fn.fnameescape(path))
    end)

    if not ok then
        vim.notify("Failed to load session " .. slot .. ": " .. err, vim.log.levels.ERROR)
        return
    end

    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(workspace))
    vim.g.current_workspace_root = vim.fn.getcwd()

    vim.schedule(function()
        session_restore.after_load(metadata)

        if type(metadata.winrestcmd) == "string" and metadata.winrestcmd ~= "" then
            pcall(vim.cmd, metadata.winrestcmd)
        end
    end)

    vim.notify("Loaded session " .. slot)
    active_session_slot = slot
end

function M.load(slot)
    slot = known_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    local path = session_path(slot)

    if not session_store.exists(slot) then
        vim.notify("Session " .. slot .. " is empty.", vim.log.levels.WARN)
        return
    end

    prepare_session_load(function()
        load_session(slot, path)
    end)
end

function M.note(slot, opts)
    session_note.open_editor(slot, opts)
end

function M.name(slot, opts)
    session_note.edit_field(slot, "name", "name", opts)
end

function M.delete(slot, force, opts)
    opts = opts or {}
    local on_deleted = opts.on_deleted

    opts.on_deleted = function(deleted_slot)
        if active_session_slot == deleted_slot then
            active_session_slot = nil
        end

        if on_deleted then
            on_deleted(deleted_slot)
        end
    end

    return session_store.delete(slot, force, opts)
end

function M.pick(opts)
    session_picker.pick(opts, {
        active_slot = function()
            return active_session_slot
        end,
        load = M.load,
        save = M.save,
        move = M.move,
        note = M.note,
        name = M.name,
        delete = M.delete,
    })
end

return M
