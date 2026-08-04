local metadata_store = require("config.sessions.metadata")
local session_paths = require("config.sessions.paths")
local session_slots = require("config.sessions.slots")

local M = {}

local read_metadata = metadata_store.read
local metadata_path = session_paths.metadata_path

local function file_mtime(path)
    local stat = vim.loop.fs_stat(path)

    if not stat or not stat.mtime or not stat.mtime.sec then
        return nil
    end

    return stat.mtime.sec
end

local function session_exists(slot)
    return vim.fn.filereadable(metadata_path(slot)) == 1
end

local function first_files(files, count)
    local selected = {}

    for index, file in ipairs(files or {}) do
        if index > count then
            break
        end

        table.insert(selected, vim.fn.fnamemodify(file, ":~:."))
    end

    return selected
end

local function split_lines(text)
    if text == "" then
        return {}
    end

    return vim.split(text, "\n", {
        plain = true,
    })
end

function M.slot_entry(slot)
    local metadata = read_metadata(slot)
    local path = metadata_path(slot)
    local exists = session_exists(slot)
    local configured = session_slots.configured_lookup()[slot] == true
    local modified_at = file_mtime(path)
    local saved_at = metadata.saved_at

    if not saved_at and modified_at then
        saved_at = os.date("%Y-%m-%d %H:%M:%S", modified_at)
    end

    local cwd = metadata.cwd or ""
    local name = metadata.name or ""
    local note = metadata.note or ""
    local files = metadata.files or {}
    local terminals = metadata.terminals or {}
    local floating_slots = metadata.floating_slots or {}
    local tree = metadata.tree or {}
    local status = exists and "Saved session" or "Empty"
    local summary = note

    if exists and name ~= "" then
        summary = name
    end

    if summary == "" and #files > 0 then
        summary = table.concat(first_files(files, 2), ", ")
    end

    if summary == "" then
        summary = exists and cwd or ""
    end

    return {
        slot = slot,
        exists = exists,
        configured = configured,
        saved_at = saved_at,
        cwd = cwd,
        name = name,
        note = note,
        files = files,
        terminal_count = #terminals,
        floating_slot_count = #floating_slots,
        tree_visible = tree.visible == true,
        path = path,
        label = exists
            and string.format(
                "[%s] %s%s: %s",
                slot,
                configured and "" or "! ",
                status,
                summary
            )
            or string.format("[%s] %s%s", slot, configured and "" or "! ", status),
        ordinal = table.concat({
            tostring(slot),
            status,
            configured and "configured" or "unlisted",
            saved_at or "",
            cwd,
            name,
            note,
            table.concat(files, " "),
            "floating_slots:" .. #floating_slots,
        }, " "),
    }
end

function M.preview_lines(entry)
    local title = "Session " .. entry.slot

    if entry.name ~= "" then
        title = title .. " - " .. entry.name
    end

    local lines = {
        title,
        "",
        "Status: " .. (entry.exists and "saved" or "empty"),
        "Slot: " .. (entry.configured and "configured" or "unlisted"),
        "Saved: " .. (entry.saved_at or "-"),
        "Cwd: " .. (entry.cwd ~= "" and entry.cwd or "-"),
        "Terminals: " .. entry.terminal_count,
        "Floating slots: " .. entry.floating_slot_count,
        "Tree: " .. (entry.tree_visible and "visible" or "hidden"),
    }

    if not entry.configured then
        table.insert(lines, "Hint: add this slot to session_slot_ids or move it to a configured slot.")
    end

    table.insert(lines, "")
    table.insert(lines, "Files:")

    if #entry.files == 0 then
        table.insert(lines, "  -")
    else
        for _, file in ipairs(first_files(entry.files, 30)) do
            table.insert(lines, "  " .. file)
        end

        if #entry.files > 30 then
            table.insert(lines, "  ... +" .. (#entry.files - 30) .. " more")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Note:")

    if entry.note == "" then
        table.insert(lines, "  -")
    else
        table.insert(lines, "")
        table.insert(lines, "")

        for _, line in ipairs(split_lines(entry.note)) do
            table.insert(lines, line)
        end
    end

    return lines
end

return M
