local themes = require("config.themes")

local M = {}

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

local function load_telescope()
    local ok, telescope = pcall(function()
        return {
            actions = require("telescope.actions"),
            action_state = require("telescope.actions.state"),
            conf = require("telescope.config").values,
            finders = require("telescope.finders"),
            pickers = require("telescope.pickers"),
        }
    end)

    if not ok then
        vim.notify("telescope.nvim is not available", vim.log.levels.ERROR)
        return nil
    end

    return telescope
end

local function picker(title, entries, opts)
    opts = opts or {}

    local telescope = load_telescope()

    if not telescope then
        return
    end

    telescope.pickers
        .new({}, {
            prompt_title = title,
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.label,
                        ordinal = entry.ordinal or entry.label,
                    }
                end,
            }),
            sorter = telescope.conf.generic_sorter({}),
            previewer = false,
            attach_mappings = function(prompt_bufnr, map)
                local select_entry = function()
                    local selected = telescope.action_state.get_selected_entry()

                    telescope.actions.close(prompt_bufnr)

                    if selected and selected.value and selected.value.action then
                        selected.value.action()
                    end
                end

                telescope.actions.select_default:replace(select_entry)

                if opts.mappings then
                    opts.mappings(prompt_bufnr, map, telescope)
                end

                return true
            end,
        })
        :find()
end

local function open_main()
    picker("Settings", {
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
            label = "Lazy settings",
            action = function()
                vim.cmd("Lazy")
            end,
        },
    })
end

local function open_theme()
    local active = current_theme()
    local entries = {
        {
            label = "< Back",
            action = open_main,
        },
    }

    for _, theme in ipairs(themes.available()) do
        local marker = theme == active and "* " or "  "

        table.insert(entries, {
            label = marker .. theme,
            ordinal = theme,
            action = function()
                if apply_theme(theme, true) then
                    themes.save(theme)
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

    table.sort(parser_list)

    local entries = {
        {
            label = "< Back",
            action = open_treesitter,
        },
    }

    for _, lang in ipairs(parser_list) do
        table.insert(entries, {
            label = lang,
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

function M.open(menu)
    if menu == "theme" then
        open_theme()
    elseif menu == "treesitter" then
        open_treesitter()
    elseif menu == "lsp" then
        open_lsp()
    else
        open_main()
    end
end

return M
