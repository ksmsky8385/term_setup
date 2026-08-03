local M = {}

M.save_path = vim.fn.stdpath("state") .. "/sidebar-settings.json"

local defaults = {
    nvim_tree_width = 30,
    agentic_width = 55,
    agentic_height = 8,
}

local limits = {
    nvim_tree_width = { min = 20, max = 80 },
    agentic_width = { min = 30, max = 120 },
    agentic_height = { min = 4, max = 20 },
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

local function apply_agentic_width(width)
    local ok_config, config = pcall(require, "agentic.config")

    if not ok_config then
        return
    end

    config.windows.width = width

    local ok_registry, registry = pcall(require, "agentic.session_registry")

    if not ok_registry or type(registry.sessions) ~= "table" then
        return
    end

    for _, session in pairs(registry.sessions) do
        local widget = type(session) == "table" and session.widget or nil

        local can_resize = widget
            and type(widget.is_open) == "function"
            and type(widget.hide) == "function"
            and type(widget.show) == "function"
        local ok_open = false
        local is_open = false

        if can_resize then
            ok_open, is_open = pcall(widget.is_open, widget)
        end

        if ok_open and is_open then
            local current_win = vim.api.nvim_get_current_win()

            pcall(widget.hide, widget)
            pcall(widget.show, widget, { focus_prompt = false })

            if vim.api.nvim_win_is_valid(current_win) then
                pcall(vim.api.nvim_set_current_win, current_win)
            end
        end
    end
end

local function apply_agentic_height(height)
    local ok_config, config = pcall(require, "agentic.config")

    if not ok_config then
        return
    end

    config.windows.input.height = height

    local ok_registry, registry = pcall(require, "agentic.session_registry")

    if not ok_registry or type(registry.sessions) ~= "table" then
        return
    end

    for _, session in pairs(registry.sessions) do
        local widget = type(session) == "table" and session.widget or nil

        if
            widget
            and type(widget.is_open) == "function"
            and type(widget.hide) == "function"
            and type(widget.show) == "function"
        then
            local ok_open, is_open = pcall(widget.is_open, widget)

            if ok_open and is_open then
                local current_win = vim.api.nvim_get_current_win()

                pcall(widget.hide, widget)
                pcall(widget.show, widget, { focus_prompt = false })

                if vim.api.nvim_win_is_valid(current_win) then
                    pcall(vim.api.nvim_set_current_win, current_win)
                end
            end
        end
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
    elseif name == "agentic_width" then
        apply_agentic_width(value)
    elseif name == "agentic_height" then
        apply_agentic_height(value)
    end

    return true
end

return M
