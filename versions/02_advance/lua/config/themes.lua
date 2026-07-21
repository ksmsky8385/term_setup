local M = {}

M.default = "default"
M.save_path = vim.fn.stdpath("state") .. "/selected-theme"
M.background_save_path = vim.fn.stdpath("state") .. "/use-terminal-background"

local transparent_groups = {
    "Normal",
    "NormalNC",
    "EndOfBuffer",
    "SignColumn",
    "FoldColumn",
    "LineNr",
    "CursorLineNr",
    "NvimTreeNormal",
    "NvimTreeNormalNC",
    "NvimTreeEndOfBuffer",
    "NeoTreeNormal",
    "NeoTreeNormalNC",
}

M.builtin = {
    "blue",
    "darkblue",
    "default",
    "delek",
    "desert",
    "elflord",
    "evening",
    "habamax",
    "industry",
    "koehler",
    "lunaperche",
    "morning",
    "murphy",
    "pablo",
    "peachpuff",
    "quiet",
    "retrobox",
    "ron",
    "shine",
    "slate",
    "sorbet",
    "torte",
    "unokai",
    "vim",
    "wildcharm",
    "zaibatsu",
    "zellner",
}

local function add_theme(list, seen, theme, source)
    if theme == nil or theme == "" or seen[theme] then
        return
    end

    seen[theme] = true
    table.insert(list, {
        name = theme,
        source = source,
    })
end

local function add_plugin_themes(list, seen, spec)
    local themes = spec.colorschemes

    if type(themes) == "string" then
        add_theme(list, seen, themes, "plugin")
        return
    end

    if type(themes) ~= "table" then
        return
    end

    for _, theme in ipairs(themes) do
        add_theme(list, seen, theme, "plugin")
    end
end

function M.available()
    local list = {}
    local seen = {}

    for _, theme in ipairs(M.builtin) do
        add_theme(list, seen, theme, "builtin")
    end

    local ok, plugin_specs = pcall(require, "plugins.themes")

    if ok then
        for _, spec in ipairs(plugin_specs) do
            add_plugin_themes(list, seen, spec)
        end
    end

    return list
end

function M.saved()
    if vim.fn.filereadable(M.save_path) == 0 then
        return M.default
    end

    local lines = vim.fn.readfile(M.save_path)
    local theme = lines[1]

    if theme == nil or theme == "" then
        return M.default
    end

    return theme
end

function M.save(theme)
    local dir = vim.fn.fnamemodify(M.save_path, ":h")

    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ theme }, M.save_path)
end

function M.terminal_background_enabled()
    if vim.fn.filereadable(M.background_save_path) == 0 then
        return false
    end

    return vim.fn.readfile(M.background_save_path)[1] == "enabled"
end

local function clear_highlight_component(group, component)
    local highlight = vim.api.nvim_get_hl(0, {
        name = group,
        link = false,
    })

    highlight[component] = nil
    vim.api.nvim_set_hl(0, group, highlight)
end

local function apply_terminal_background()
    if not M.terminal_background_enabled() then
        return
    end

    for _, group in ipairs(transparent_groups) do
        clear_highlight_component(group, "bg")
    end
end

function M.set_terminal_background(enabled)
    local dir = vim.fn.fnamemodify(M.background_save_path, ":h")

    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ enabled and "enabled" or "disabled" }, M.background_save_path)

    if enabled then
        apply_terminal_background()
        return
    end

    -- Reloading the colorscheme restores the background highlights that were
    -- cleared while terminal-background mode was enabled.
    local theme = vim.g.colors_name or M.saved()
    pcall(vim.cmd.colorscheme, theme)
end

function M.toggle_terminal_background()
    local enabled = not M.terminal_background_enabled()

    M.set_terminal_background(enabled)
    return enabled
end

function M.setup_terminal_background()
    local group = vim.api.nvim_create_augroup("TerminalBackground", { clear = true })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            apply_terminal_background()
            -- Some UI plugins rebuild their highlights in their own
            -- ColorScheme callback. Run once more after those callbacks.
            vim.schedule(apply_terminal_background)
        end,
        desc = "Keep the terminal background visible after changing themes",
    })

    apply_terminal_background()
end

function M.apply_saved()
    M.setup_terminal_background()

    local theme = M.saved()
    local ok = pcall(vim.cmd.colorscheme, theme)

    if not ok and theme ~= M.default then
        pcall(vim.cmd.colorscheme, M.default)
    end
end

return M
