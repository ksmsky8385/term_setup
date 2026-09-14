local M = {}

M.save_path = vim.fn.stdpath("state") .. "/ui-toggle-settings.json"

local defaults = {
    minimap = false,
    scrollview = false,
    editor_autopairs = true,
    editor_line_numbers = "absolute",
    editor_wrap = true,
    editor_linebreak = false,
    editor_breakindent = false,
    editor_cursorline = false,
    editor_cursorcolumn = false,
    editor_list = true,
    editor_spell = false,
}

local values

local function valid(name, value)
    if name == "editor_line_numbers" then
        return vim.tbl_contains({ "absolute", "relative", "hybrid", "off" }, value)
    end
    return defaults[name] ~= nil and type(value) == "boolean"
end

local function legacy_path(name)
    return vim.fn.stdpath("state") .. "/toggles/" .. name
end

local function save()
    local dir = vim.fn.fnamemodify(M.save_path, ":h")

    vim.fn.mkdir(dir, "p")

    local result = vim.fn.writefile({ vim.json.encode(values) }, M.save_path)
    assert(result == 0, "Failed to save UI toggle settings")
end

local function load()
    if values then
        return
    end

    values = vim.deepcopy(defaults)

    if vim.fn.filereadable(M.save_path) == 1 then
        local ok, saved =
            pcall(vim.json.decode, table.concat(vim.fn.readfile(M.save_path), "\n"))

        if ok and type(saved) == "table" then
            for name in pairs(defaults) do
                if valid(name, saved[name]) then
                    values[name] = saved[name]
                end
            end
        end
    end

    local migrated = false

    for _, name in ipairs({ "minimap", "scrollview" }) do
        local path = legacy_path(name)

        if vim.fn.filereadable(path) == 1 then
            local lines = vim.fn.readfile(path)
            values[name] = lines[1] == "enabled"
            migrated = true
        end
    end

    save()

    if migrated then
        for _, name in ipairs({ "minimap", "scrollview" }) do
            vim.fn.delete(legacy_path(name))
        end

        vim.fn.delete(vim.fn.stdpath("state") .. "/toggles", "d")
    end
end

function M.read(name, default)
    load()

    if values[name] == nil then
        return default
    end

    return values[name]
end

function M.write(name, enabled)
    load()

    assert(defaults[name] ~= nil, "Unknown UI toggle setting: " .. name)
    assert(valid(name, enabled), "Invalid UI toggle setting: " .. name)

    values[name] = enabled
    save()
end

return M
