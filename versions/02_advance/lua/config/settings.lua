local themes = require("config.themes")
local telescope_picker = require("config.picker")

local M = {}

local recommended_treesitter_langs = {
    "c",
    "python",
    "lua",
    "bash",
    "make",
    "json",
    "yaml",
    "toml",
    "markdown",
    "markdown_inline",
    "vim",
    "vimdoc",
}

local function current_theme()
    return vim.g.colors_name or themes.default
end

local function apply_theme(theme, notify)
    local ok, err = pcall(vim.cmd.colorscheme, theme)

    if ok then
        if notify then
            vim.notify("Change Theme: " .. theme)
        end
        return true
    end

    if notify then
        vim.notify("Failed Change Theme: " .. err, vim.log.levels.ERROR)
    end

    return false
end

local function picker(title, entries, opts)
    telescope_picker.action_picker(title, entries, opts)
end

local function open_main()
    picker("Settings", {
        {
            label = "Buffer settings",
            action = function()
                M.open("buffer")
            end,
        },
        {
            label = "Change theme",
            action = function()
                M.open("theme")
            end,
        },
        {
            label = "Tree-sitter settings",
            action = function()
                M.open("treesitter")
            end,
        },
        {
            label = "LSP settings",
            action = function()
                M.open("lsp")
            end,
        },
        {
            label = "Debugger settings",
            action = function()
                M.open("debugger")
            end,
        },
        {
            label = "Snippet settings",
            action = function()
                M.open("snippets")
            end,
        },
        {
            label = "Lazy settings",
            action = function()
                vim.cmd("Lazy")
            end,
        },
    })
end

local function open_buffer()
    local autosave = require("config.autosave")
    local auto_close = require("config.buffers.auto_close")
    local end_of_buffer = require("config.end_of_buffer")

    picker("Settings > Buffer", {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Auto save: "
                .. (autosave.enabled() and "enabled" or "disabled"),
            action = function()
                autosave.toggle()
                M.open("buffer")
            end,
        },
        {
            label = "Auto close buffer: "
                .. (auto_close.enabled() and "enabled" or "disabled"),
            action = function()
                auto_close.toggle()
                M.open("buffer")
            end,
        },
        {
            label = "End-of-buffer ~ markers: "
                .. (end_of_buffer.enabled() and "enabled" or "disabled"),
            action = function()
                end_of_buffer.toggle()
                M.open("buffer")
            end,
        },
    })
end

local function open_theme()
    local active = current_theme()
    local terminal_background = themes.terminal_background_enabled()
    local entries = {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Use terminal background: "
                .. (terminal_background and "enabled" or "disabled"),
            ordinal = "terminal background",
            action = function()
                local enabled = themes.toggle_terminal_background()
                vim.notify(
                    "Terminal background: " .. (enabled and "enabled" or "disabled")
                )
                M.open("theme")
            end,
        },
    }

    for _, theme in ipairs(themes.available()) do
        local marker = theme.name == active and "* " or "  "
        local label = theme.name

        if theme.source == "plugin" then
            label = "+ " .. label
        end

        table.insert(entries, {
            label = marker .. label,
            ordinal = theme.name,
            action = function()
                if apply_theme(theme.name, true) then
                    themes.save(theme.name)
                    M.open("theme")
                end
            end,
        })
    end

    picker("Settings > Theme", entries)
end

local open_treesitter

local function open_treesitter_parser_list()
    local ok, parsers = pcall(require, "nvim-treesitter.parsers")

    if not ok then
        vim.notify("nvim-treesitter parsers are not available", vim.log.levels.ERROR)
        return
    end

    local parser_list = parsers.available_parsers()

    table.sort(parser_list)

    local entries = {
        {
            label = "< Back",
            action = open_treesitter,
        },
    }

    for _, lang in ipairs(parser_list) do
        local installed = #vim.api.nvim_get_runtime_file(
            "parser/" .. lang .. ".so",
            false
        ) > 0
        local status = installed and "[x]" or "[ ]"

        table.insert(entries, {
            label = string.format("%s %s", status, lang),
            ordinal = lang,
            action = function()
                if installed then
                    vim.cmd("TSMyUninstall " .. vim.fn.fnameescape(lang))
                else
                    vim.cmd("TSMyInstall " .. vim.fn.fnameescape(lang))
                end
            end,
        })
    end

    picker("Tree-sitter Parsers", entries)
end

local function open_treesitter_install()
    local ok, parsers = pcall(require, "nvim-treesitter.parsers")

    if not ok then
        vim.notify("nvim-treesitter parsers are not available", vim.log.levels.ERROR)
        return
    end

    local parser_list = parsers.available_parsers()
    local configured = {}
    local max_lang_len = 0

    table.sort(parser_list)

    for _, lang in ipairs(recommended_treesitter_langs) do
        configured[lang] = true
    end

    for _, lang in ipairs(parser_list) do
        max_lang_len = math.max(max_lang_len, #lang)
    end

    local entries = {
        {
            label = "< Back",
            action = open_treesitter,
        },
        {
            label = "[x] installed    [ ] not installed    * recommended",
        },
    }

    for _, lang in ipairs(parser_list) do
        local installed = #vim.api.nvim_get_runtime_file(
            "parser/" .. lang .. ".so",
            false
        ) > 0
        local status = installed and "[x]" or "[ ]"
        local marker = configured[lang] and "*" or " "

        table.insert(entries, {
            label = string.format(
                "%s %s %-" .. max_lang_len .. "s",
                status,
                marker,
                lang
            ),
            ordinal = lang,
            action = function()
                vim.cmd("TSMyInstall " .. vim.fn.fnameescape(lang))
            end,
        })
    end

    picker("Install Tree-sitter Parser", entries)
end

local function open_treesitter_remove()
    local ok, parsers = pcall(require, "nvim-treesitter.parsers")

    if not ok then
        vim.notify("nvim-treesitter parsers are not available", vim.log.levels.ERROR)
        return
    end

    local parser_list = parsers.available_parsers()

    table.sort(parser_list)

    local entries = {
        {
            label = "< Back",
            action = open_treesitter,
        },
    }

    for _, lang in ipairs(parser_list) do
        local installed = #vim.api.nvim_get_runtime_file(
            "parser/" .. lang .. ".so",
            false
        ) > 0

        if installed then
            table.insert(entries, {
                label = lang,
                action = function()
                    vim.cmd("TSMyUninstall " .. vim.fn.fnameescape(lang))
                end,
            })
        end
    end

    picker("Remove Tree-sitter Parser", entries)
end

open_treesitter = function()
    picker("Settings > Tree-sitter", {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Parser list",
            action = open_treesitter_parser_list,
        },
        {
            label = "Parser install",
            action = open_treesitter_install,
        },
        {
            label = "Parser remove",
            action = open_treesitter_remove,
        },
        {
            label = "Parser update",
            action = function()
                vim.cmd("TSMyUpdate")
            end,
        },
    })
end

local function open_lsp()
    picker("Settings > LSP", {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Server list",
            action = function()
                vim.cmd("LSPMyList")
            end,
        },
        {
            label = "Server install",
            action = function()
                vim.cmd("LSPMyInstall")
            end,
        },
        {
            label = "Server remove",
            action = function()
                vim.cmd("LSPMyUninstall")
            end,
        },
        {
            label = "Update registry",
            action = function()
                vim.cmd("LSPMyUpdate")
            end,
        },
        {
            label = "Open Mason",
            action = function()
                vim.cmd("Mason")
            end,
        },
    })
end

local function open_debugger()
    local debugger = require("config.debugger")

    picker("Settings > Debugger", {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Args prompt: "
                .. (debugger.prompt_args_enabled() and "enabled" or "disabled"),
            action = function()
                debugger.toggle_prompt_args()
                M.open("debugger")
            end,
        },
        {
            label = "Adapter list",
            action = function()
                vim.cmd("DAPMyList")
            end,
        },
        {
            label = "Adapter install",
            action = function()
                vim.cmd("DAPMyInstall")
            end,
        },
        {
            label = "Adapter remove",
            action = function()
                vim.cmd("DAPMyUninstall")
            end,
        },
        {
            label = "Show runtime path",
            action = function()
                vim.cmd("DAPPath")
            end,
        },
        {
            label = "Update registry",
            action = function()
                vim.cmd("DAPMyUpdate")
            end,
        },
        {
            label = "Open Mason",
            action = function()
                vim.cmd("Mason")
            end,
        },
    })
end

local function open_snippets()
    local completion = require("config.completion")
    local state = completion.state

    picker("Settings > Snippets", {
        {
            label = "< Back",
            action = open_main,
        },
        {
            label = "Snippets: "
                .. (state.snippets and "enabled" or "disabled"),
            action = function()
                completion.toggle_snippets()
                M.open("snippets")
            end,
        },
        {
            label = "Completion source: "
                .. (state.snippet_source and "enabled" or "disabled"),
            action = function()
                completion.toggle_snippet_source()
                M.open("snippets")
            end,
        },
        {
            label = "Friendly snippets: "
                .. (state.friendly_snippets and "enabled" or "disabled"),
            action = function()
                completion.toggle_friendly_snippets()
                M.open("snippets")
            end,
        },
        {
            label = "Reload snippets",
            action = function()
                completion.reload_snippets()
                M.open("snippets")
            end,
        },
    })
end

function M.open(menu)
    if menu == "buffer" then
        open_buffer()
    elseif menu == "theme" then
        open_theme()
    elseif menu == "treesitter" then
        open_treesitter()
    elseif menu == "lsp" then
        open_lsp()
    elseif menu == "debugger" then
        open_debugger()
    elseif menu == "snippets" then
        open_snippets()
    else
        open_main()
    end
end

return M
