local M = {}

M.save_path = vim.fn.stdpath("state") .. "/sidebar-settings.json"

local defaults = {
    nvim_tree_width = 30,
}

local limits = {
    nvim_tree_width = { min = 20, max = 80 },
}

local values

local function valid_value(name, value)
    local range = limits[name]

    return range
        and type(value) == "number"
        and value == math.floor(value)
        and value >= range.min
        and value <= range.max
end

local function save()
    local dir = vim.fn.fnamemodify(M.save_path, ":h")

    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ vim.json.encode(values) }, M.save_path)
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
                if valid_value(name, saved[name]) then
                    values[name] = saved[name]
                end
            end
        end
    end

    save()
end

local function apply_nvim_tree_width(width)
    local ok, api = pcall(require, "nvim-tree.api")

    if ok and api.tree and type(api.tree.resize) == "function" then
        pcall(api.tree.resize, { absolute = width })
    end
end

function M.get(name)
    load()
    return values[name]
end

function M.range(name)
    return limits[name] and vim.deepcopy(limits[name]) or nil
end

function M.set(name, value)
    load()

    value = tonumber(value)

    if not valid_value(name, value) then
        return false
    end

    values[name] = value
    save()

    if name == "nvim_tree_width" then
        apply_nvim_tree_width(value)
    end

    return true
end

return M
