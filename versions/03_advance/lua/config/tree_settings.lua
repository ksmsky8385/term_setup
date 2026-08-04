local M = {}

M.save_path = vim.fn.stdpath("state") .. "/file-tree-settings.json"

local defaults = {
    dotfiles = false,
    git_ignored = true,
}

local values

local function load()
    if values then
        return
    end

    values = vim.deepcopy(defaults)

    if vim.fn.filereadable(M.save_path) == 0 then
        return
    end

    local ok, saved =
        pcall(vim.json.decode, table.concat(vim.fn.readfile(M.save_path), "\n"))

    if not ok or type(saved) ~= "table" then
        return
    end

    for name, default in pairs(defaults) do
        if type(saved[name]) == type(default) then
            values[name] = saved[name]
        end
    end
end

local function save()
    local dir = vim.fn.fnamemodify(M.save_path, ":h")

    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ vim.json.encode(values) }, M.save_path)
end

function M.get(name)
    load()
    return values[name]
end

function M.toggle(name)
    load()

    if type(defaults[name]) ~= "boolean" then
        return nil
    end

    values[name] = not values[name]
    save()
    return values[name]
end

return M
