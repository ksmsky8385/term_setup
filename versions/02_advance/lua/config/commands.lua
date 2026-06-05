local about = require("config.about")
local settings = require("config.settings")

local function open_settings(menu)
    settings.open(menu)
end

vim.api.nvim_create_user_command("Settings", function()
    open_settings()
end, {
    desc = "Open settings",
})

vim.api.nvim_create_user_command("SettingsTheme", function()
    open_settings("theme")
end, {
    desc = "Open theme settings",
})

vim.api.nvim_create_user_command("SettingsTreeSitter", function()
    open_settings("treesitter")
end, {
    desc = "Open Tree-sitter settings",
})

vim.api.nvim_create_user_command("SettingsLSP", function()
    open_settings("lsp")
end, {
    desc = "Open LSP settings",
})

vim.api.nvim_create_user_command("SettingsSnippets", function()
    open_settings("snippets")
end, {
    desc = "Open snippet settings",
})

vim.api.nvim_create_user_command("ThemePick", function()
    open_settings("theme")
end, {
    desc = "Alias for SettingsTheme",
})

vim.api.nvim_create_user_command("TSSettings", function()
    open_settings("treesitter")
end, {
    desc = "Alias for SettingsTreeSitter",
})

vim.api.nvim_create_user_command("LSPSettings", function()
    open_settings("lsp")
end, {
    desc = "Alias for SettingsLSP",
})

vim.api.nvim_create_user_command("SnippetSettings", function()
    open_settings("snippets")
end, {
    desc = "Alias for SettingsSnippets",
})

vim.api.nvim_create_user_command("MainSettings", function()
    open_settings()
end, {
    desc = "Alias for Settings",
})

vim.api.nvim_create_user_command("AboutNeovim", function()
    about.open()
end, {})

vim.api.nvim_create_user_command("TKill", function()
    require("config.terminal").kill_current_terminal(true)
end, {})

vim.api.nvim_create_user_command("WorkspacePick", function()
    vim.ui.input({
        prompt = "Workspace path: ",
        default = vim.g.current_workspace_root or vim.fn.getcwd(),
        completion = "dir",
    }, function(path)
        if path == nil or path == "" then
            return
        end

        path = vim.fn.expand(path)

        if vim.fn.isdirectory(path) == 0 then
            vim.notify("Directory not found: " .. path, vim.log.levels.ERROR)
            return
        end

        vim.cmd("cd " .. vim.fn.fnameescape(path))
        vim.g.current_workspace_root = vim.fn.getcwd()

        vim.notify(" -> Workspace changed: " .. vim.g.current_workspace_root)
    end)
end, {})

vim.api.nvim_create_user_command("TreeToggle", function()
    local ok, api = pcall(require, "nvim-tree.api")

    if not ok then
        vim.notify("Can't call nvim-tree api", vim.log.levels.ERROR)
        return
    end

    api.tree.toggle({
        focus = true,
    })
end, {})
