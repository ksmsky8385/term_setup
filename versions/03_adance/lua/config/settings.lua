local themes = require("config.themes")

local M = {}

local state = {
    buf = nil,
    menu = "main",
    stack = {},
    rows = {},
    preview_origin = nil,
    committed_theme = nil,
}

local menus = {}

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

local function restore_preview()
    if state.preview_origin then
        apply_theme(state.preview_origin, false)
        state.preview_origin = nil
        state.committed_theme = nil
    end
end

local function close()
    restore_preview()

    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.cmd, "DashboardHome")
    end
end

local function set_lines(lines)
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
end

local function menu_title()
    if state.menu == "theme" then
        return "Settings > Theme"
    end

    if state.menu == "treesitter" then
        return "Settings > Tree-sitter"
    end

    if state.menu == "lsp" then
        return "Settings > LSP"
    end

    return "Settings"
end

local function render()
    local menu = menus[state.menu]()
    state.rows = menu.rows

    local lines = {
        "",
        "  " .. menu_title(),
        "  " .. string.rep("-", vim.fn.strdisplaywidth(menu_title())),
        "",
    }

    table.insert(lines, "  < Back")
    table.insert(lines, "")

    for _, row in ipairs(state.rows) do
        table.insert(lines, "  " .. row.label)
    end

    table.insert(lines, "")
    table.insert(lines, "  j/k or arrows: move    Enter/l: open    h/b: back    q: close")

    set_lines(lines)

    local first_row = 5
    vim.api.nvim_win_set_cursor(0, { first_row, 2 })
end

local function selected_index()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local start = 7
    local idx = row - start + 1

    if idx >= 1 and idx <= #state.rows then
        return idx
    end

    return nil
end

local function move(delta)
    local back_row = 5
    local start = 7
    local last = start + #state.rows - 1
    local row = vim.api.nvim_win_get_cursor(0)[1]

    if row == back_row then
        row = delta > 0 and start or last
    else
        row = row + delta
    end

    if row == start - 1 then
        row = back_row
    elseif row < back_row then
        row = last
    elseif row > last then
        row = back_row
    end

    vim.api.nvim_win_set_cursor(0, { row, 2 })
end

local function enter_menu(name)
    if state.menu == "theme" then
        restore_preview()
    end

    table.insert(state.stack, state.menu)
    state.menu = name
    render()
end

local function back()
    if state.menu == "theme" then
        restore_preview()
    end

    local previous = table.remove(state.stack)

    if previous then
        state.menu = previous
        render()
    else
        close()
    end
end

local function activate()
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

    if cursor_row == 5 then
        back()
        return
    end

    local idx = selected_index()

    if not idx then
        return
    end

    local row = state.rows[idx]

    if row.menu then
        enter_menu(row.menu)
        return
    end

    if row.action then
        row.action()
    end
end

local function preview_theme()
    if state.menu ~= "theme" then
        return
    end

    local idx = selected_index()

    if not idx then
        return
    end

    local row = state.rows[idx]

    if not row.theme then
        return
    end

    if not state.preview_origin then
        state.preview_origin = current_theme()
    end

    if state.committed_theme ~= row.theme then
        apply_theme(row.theme, false)
    end
end

local function setup_buffer()
    vim.cmd("enew")
    state.buf = vim.api.nvim_get_current_buf()

    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.filetype = "nvim-settings"
    vim.wo.cursorline = true

    local opts = {
        buffer = true,
        silent = true,
    }

    vim.keymap.set("n", "j", function()
        move(1)
        preview_theme()
    end, opts)
    vim.keymap.set("n", "<Down>", function()
        move(1)
        preview_theme()
    end, opts)
    vim.keymap.set("n", "k", function()
        move(-1)
        preview_theme()
    end, opts)
    vim.keymap.set("n", "<Up>", function()
        move(-1)
        preview_theme()
    end, opts)
    vim.keymap.set("n", "l", activate, opts)
    vim.keymap.set("n", "<CR>", activate, opts)
    vim.keymap.set("n", "h", back, opts)
    vim.keymap.set("n", "b", back, opts)
    vim.keymap.set("n", "q", close, opts)
    vim.keymap.set("n", "<Esc>", close, opts)

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = state.buf,
        once = true,
        callback = restore_preview,
    })
end

menus.main = function()
    return {
        rows = {
            {
                label = "Change theme",
                menu = "theme",
            },
            {
                label = "Tree-sitter settings",
                menu = "treesitter",
            },
            {
                label = "LSP settings",
                menu = "lsp",
            },
            {
                label = "Lazy settings",
                action = function()
                    close()
                    vim.cmd("Lazy")
                end,
            },
        },
    }
end

menus.theme = function()
    local rows = {}
    local active = current_theme()

    for _, theme in ipairs(themes.available()) do
        local marker = theme == active and "* " or "  "

        table.insert(rows, {
            label = marker .. theme,
            theme = theme,
            action = function()
                if apply_theme(theme, true) then
                    themes.save(theme)
                    state.preview_origin = nil
                    state.committed_theme = theme
                    render()
                end
            end,
        })
    end

    return {
        rows = rows,
    }
end

menus.treesitter = function()
    return {
        rows = {
            {
                label = "Tree-sitter parser list",
                action = function()
                    vim.cmd("TSMyList")
                end,
            },
            {
                label = "Tree-sitter parser install",
                action = function()
                    vim.ui.input({
                        prompt = "Install parser name: ",
                    }, function(lang)
                        if lang and lang ~= "" then
                            vim.cmd("TSMyInstall " .. lang)
                        end
                    end)
                end,
            },
            {
                label = "Tree-sitter parser remove",
                action = function()
                    vim.ui.input({
                        prompt = "Remove parser name: ",
                    }, function(lang)
                        if lang and lang ~= "" then
                            vim.cmd("TSMyUninstall " .. lang)
                        end
                    end)
                end,
            },
            {
                label = "Tree-sitter parser update",
                action = function()
                    vim.cmd("TSMyUpdate")
                end,
            },
        },
    }
end

menus.lsp = function()
    return {
        rows = {
            {
                label = "LSP server list",
                action = function()
                    vim.cmd("LSPMyList")
                end,
            },
            {
                label = "LSP server install",
                action = function()
                    vim.ui.input({
                        prompt = "Install LSP server name: ",
                    }, function(server)
                        if server and server ~= "" then
                            vim.cmd("LSPMyInstall " .. server)
                        end
                    end)
                end,
            },
            {
                label = "LSP server remove",
                action = function()
                    vim.ui.input({
                        prompt = "Remove LSP server name: ",
                    }, function(server)
                        if server and server ~= "" then
                            vim.cmd("LSPMyUninstall " .. server)
                        end
                    end)
                end,
            },
            {
                label = "LSP server update registry",
                action = function()
                    vim.cmd("LSPMyUpdate")
                end,
            },
            {
                label = "Open Mason",
                action = function()
                    close()
                    vim.cmd("Mason")
                end,
            },
        },
    }
end

function M.open(menu)
    state.menu = menu or "main"
    state.stack = {}
    state.rows = {}
    state.preview_origin = nil
    state.committed_theme = nil

    setup_buffer()
    render()

    if state.menu == "theme" then
        preview_theme()
    end
end

return M
