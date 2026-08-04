local M = {}

local cmp_ref = nil

M.state = {
    completion = true,
    snippets = true,
    snippet_source = true,
    friendly_snippets = true,
}

local function load_cmp()
    if cmp_ref then
        return cmp_ref
    end

    local ok, cmp = pcall(require, "cmp")

    if not ok then
        return nil
    end

    cmp_ref = cmp
    return cmp_ref
end

local function load_luasnip()
    local ok, luasnip = pcall(require, "luasnip")

    if not ok then
        return nil
    end

    return luasnip
end

local function custom_snippet_path()
    return vim.fn.stdpath("config") .. "/snippets"
end

local function source_groups()
    local primary = {
        { name = "nvim_lsp" },
        { name = "path" },
    }

    if M.state.snippets and M.state.snippet_source then
        table.insert(primary, {
            name = "luasnip",
            option = {
                show_autosnippets = false,
            },
        })
    end

    return primary, {
        { name = "buffer" },
    }
end

local function can_expand_or_jump(luasnip)
    if luasnip.expandable_or_jumpable then
        return luasnip.expandable_or_jumpable()
    end

    if luasnip.expand_or_jumpable then
        return luasnip.expand_or_jumpable()
    end

    return false
end

local function can_jump(luasnip, direction)
    if luasnip.jumpable then
        return luasnip.jumpable(direction)
    end

    return false
end

function M.sources()
    local cmp = load_cmp()

    if not cmp then
        return {}
    end

    local primary, secondary = source_groups()
    return cmp.config.sources(primary, secondary)
end

function M.refresh_sources()
    local cmp = load_cmp()

    if not cmp then
        return false
    end

    cmp.setup({
        sources = M.sources(),
    })

    return true
end

function M.load_friendly_snippets()
    if not M.state.friendly_snippets then
        return false
    end

    local ok, loader = pcall(require, "luasnip.loaders.from_vscode")

    if not ok then
        return false
    end

    loader.lazy_load()
    return true
end

function M.load_custom_snippets()
    local ok, loader = pcall(require, "luasnip.loaders.from_vscode")

    if not ok then
        return false
    end

    local path = custom_snippet_path()

    if vim.fn.isdirectory(path) == 0 then
        return false
    end

    loader.lazy_load({
        paths = {
            path,
        },
    })

    return true
end

function M.reload_snippets()
    local luasnip = load_luasnip()

    if not luasnip then
        vim.notify("LuaSnip is not available", vim.log.levels.ERROR)
        return false
    end

    if luasnip.cleanup then
        luasnip.cleanup()
    end

    M.load_friendly_snippets()
    M.load_custom_snippets()
    vim.notify("Snippets reloaded")
    return true
end

function M.toggle_completion()
    local cmp = load_cmp()
    M.state.completion = not M.state.completion

    if cmp and not M.state.completion then
        cmp.abort()
    end

    vim.notify("Completion " .. (M.state.completion and "enabled" or "disabled"))
end

function M.toggle_snippets()
    M.state.snippets = not M.state.snippets
    M.refresh_sources()
    vim.notify("Snippets " .. (M.state.snippets and "enabled" or "disabled"))
end

function M.toggle_snippet_source()
    M.state.snippet_source = not M.state.snippet_source
    M.refresh_sources()
    vim.notify(
        "Snippet completion "
            .. (M.state.snippet_source and "enabled" or "disabled")
    )
end

function M.toggle_friendly_snippets()
    M.state.friendly_snippets = not M.state.friendly_snippets

    if M.state.friendly_snippets then
        M.load_friendly_snippets()
    end

    vim.notify(
        "Friendly snippets "
            .. (M.state.friendly_snippets and "enabled" or "disabled")
    )
end

function M.setup()
    local cmp = load_cmp()

    if not cmp then
        return
    end

    local luasnip = load_luasnip()

    if luasnip then
        luasnip.config.setup({
            history = true,
            updateevents = "TextChanged,TextChangedI",
        })
    end

    M.load_friendly_snippets()
    M.load_custom_snippets()

    cmp.setup({
        enabled = function()
            return M.state.completion
        end,
        snippet = {
            expand = function(args)
                local snip = load_luasnip()

                if snip and M.state.snippets then
                    snip.lsp_expand(args.body)
                elseif vim.snippet then
                    vim.snippet.expand(args.body)
                end
            end,
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({
                select = false,
            }),
            ["<C-n>"] = cmp.mapping.select_next_item({
                behavior = cmp.SelectBehavior.Select,
            }),
            ["<C-p>"] = cmp.mapping.select_prev_item({
                behavior = cmp.SelectBehavior.Select,
            }),
            ["<Tab>"] = cmp.mapping(function(fallback)
                local snip = load_luasnip()

                if M.state.snippets and snip and can_expand_or_jump(snip) then
                    snip.expand_or_jump()
                else
                    fallback()
                end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
                local snip = load_luasnip()

                if M.state.snippets and snip and can_jump(snip, -1) then
                    snip.jump(-1)
                else
                    fallback()
                end
            end, { "i", "s" }),
        }),
        sources = M.sources(),
    })

    vim.keymap.set("n", "<leader>ct", M.toggle_completion, {
        noremap = true,
        silent = true,
        desc = "Toggle completion",
    })

    vim.keymap.set("n", "<leader>st", M.toggle_snippet_source, {
        noremap = true,
        silent = true,
        desc = "Toggle snippet completion",
    })

    vim.keymap.set("n", "<leader>sr", M.reload_snippets, {
        noremap = true,
        silent = true,
        desc = "Reload snippets",
    })
end

return M
