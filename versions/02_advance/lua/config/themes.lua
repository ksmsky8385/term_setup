local M = {}

M.default = "default"
M.save_path = vim.fn.stdpath("state") .. "/selected-theme"

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

function M.apply_saved()
    local theme = M.saved()
    local ok = pcall(vim.cmd.colorscheme, theme)

    if not ok and theme ~= M.default then
        pcall(vim.cmd.colorscheme, M.default)
    end
end

return M
