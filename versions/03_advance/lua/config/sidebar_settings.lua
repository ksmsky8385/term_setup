local M = {}

M.save_path = vim.fn.stdpath("state") .. "/sidebar-settings.json"

local defaults = {
    nvim_tree_position = "left",
    nvim_tree_width = 30,
    agentic_position = "right",
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
    if name == "nvim_tree_position" or name == "agentic_position" then
        return value == "left" or value == "right"
    end

    local range = limits[name]

    return range
        and type(value) == "number"
        and value == math.floor(value)
        and value >= range.min
        and value <= range.max
end

local function apply_nvim_tree_position(position)
    local ok_config, config = pcall(require, "nvim-tree.config")

    if not ok_config or not config.g then
        return
    end

    config.g.view.side = position

    local ok_view, view = pcall(require, "nvim-tree.view")

    if ok_view and view.is_visible() then
        local current_win = vim.api.nvim_get_current_win()

        pcall(view.reposition_window)

        if vim.api.nvim_win_is_valid(current_win) then
            pcall(vim.api.nvim_set_current_win, current_win)
        end
    end
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

local function apply_agentic_position(position)
    local ok_config, config = pcall(require, "agentic.config")

    if not ok_config then
        return
    end

    config.windows.position = position

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

            widget.current_position = position

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

function M.restore_agentic_width()
    load()

    local ok_registry, registry = pcall(require, "agentic.session_registry")

    if not ok_registry or type(registry.sessions) ~= "table" then
        return
    end

    for _, session in pairs(registry.sessions) do
        local widget = type(session) == "table" and session.widget or nil
        local chat_win = widget
            and type(widget.win_nrs) == "table"
            and widget.win_nrs.chat

        if chat_win and vim.api.nvim_win_is_valid(chat_win) then
            vim.wo[chat_win].winfixwidth = true

            if vim.api.nvim_win_get_width(chat_win) ~= values.agentic_width then
                pcall(vim.api.nvim_win_set_width, chat_win, values.agentic_width)
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

    if limits[name] then
        value = tonumber(value)
    end

    if not valid_value(name, value) then
        return false
    end

    values[name] = value
    save()

    if name == "nvim_tree_position" then
        apply_nvim_tree_position(value)
    elseif name == "nvim_tree_width" then
        apply_nvim_tree_width(value)
    elseif name == "agentic_position" then
        apply_agentic_position(value)
    elseif name == "agentic_width" then
        apply_agentic_width(value)
    elseif name == "agentic_height" then
        apply_agentic_height(value)
    end

    return true
end

return M
