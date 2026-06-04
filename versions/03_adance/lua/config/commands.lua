local about = require("config.about")
local settings = require("config.settings")

vim.api.nvim_create_user_command("ThemePick", function()
    settings.open("theme")
end, {})

vim.api.nvim_create_user_command("TSSettings", function()
    settings.open("treesitter")
end, {})

vim.api.nvim_create_user_command("MainSettings", function()
    settings.open()
end, {})

vim.api.nvim_create_user_command("AboutNeovim", function()
    about.open()
end, {})

vim.api.nvim_create_user_command("TKill", function()
    require("config.terminal").kill_current_terminal()
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
