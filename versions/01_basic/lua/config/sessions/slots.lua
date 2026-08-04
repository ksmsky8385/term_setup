local paths = require("config.sessions.paths")

local M = {}

local session_slot_ids = {
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
}

function M.configured_ids()
    return vim.deepcopy(session_slot_ids)
end

function M.configured_lookup()
    local lookup = {}

    for _, slot in ipairs(session_slot_ids) do
        lookup[slot] = true
    end

    return lookup
end

function M.normalize(slot)
    if slot == nil then
        return nil
    end

    slot = tostring(slot)

    if slot == "" or not slot:match("^[%w]+$") then
        return nil
    end

    return slot
end

function M.configured(slot)
    slot = M.normalize(slot)

    if not slot or not M.configured_lookup()[slot] then
        return nil
    end

    return slot
end

function M.configured_message()
    return "Session slot must be one of: " .. table.concat(session_slot_ids, ", ")
end

local function slot_id_from_filename(filename)
    return filename:match("^slot%-([%w]+)%.vim$")
        or filename:match("^slot%-([%w]+)%.json$")
end

function M.disk_ids()
    local ids = {}
    local seen = {}

    if vim.fn.isdirectory(paths.dir) == 0 then
        return ids
    end

    for _, filename in ipairs(vim.fn.readdir(paths.dir)) do
        local slot = slot_id_from_filename(filename)

        if slot and not seen[slot] then
            table.insert(ids, slot)
            seen[slot] = true
        end
    end

    table.sort(ids)

    return ids
end

function M.known_ids()
    local ids = {}
    local seen = {}

    for _, slot in ipairs(session_slot_ids) do
        table.insert(ids, slot)
        seen[slot] = true
    end

    for _, slot in ipairs(M.disk_ids()) do
        if not seen[slot] then
            table.insert(ids, slot)
            seen[slot] = true
        end
    end

    return ids
end

function M.known(slot)
    slot = M.normalize(slot)

    if not slot then
        return nil
    end

    for _, known in ipairs(M.known_ids()) do
        if known == slot then
            return slot
        end
    end

    return nil
end

return M
