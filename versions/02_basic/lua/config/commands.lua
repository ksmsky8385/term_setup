local about = require("config.about")

local MY_THEMES = {
    "vscode",
    "onedark",
    "tokyonight",
    "habamax",
    "slate",
    "desert",
    "industry",
}

vim.api.nvim_create_user_command("ThemePick", function()
    vim.ui.select(MY_THEMES, {
        prompt = "변경할 테마를 선택하세요:",
    }, function(choice)
        if choice then
            vim.cmd.colorscheme(choice)
            vim.notify("테마 변경: " .. choice)
        end
    end)
end, {})

vim.api.nvim_create_user_command("TSSettings", function()
    local menu = {
        "1. Tree-sitter parser list",
        "2. Tree-sitter parser install",
        "3. Tree-sitter parser remove",
        "4. Tree-sitter parser update",
    }

    vim.ui.select(menu, {
        prompt = "Tree-sitter settings:",
    }, function(choice)
        if choice == nil then
            return
        end

        if choice:match("^1") then
            vim.cmd("TSMyList")
        elseif choice:match("^2") then
            vim.ui.input({
                prompt = "Install parser name: ",
            }, function(lang)
                if lang and lang ~= "" then
                    vim.cmd("TSMyInstall " .. lang)
                end
            end)
        elseif choice:match("^3") then
            vim.ui.input({
                prompt = "Remove parser name: ",
            }, function(lang)
                if lang and lang ~= "" then
                    vim.cmd("TSMyUninstall " .. lang)
                end
            end)
        elseif choice:match("^4") then
            vim.cmd("TSMyUpdate")
        end
    end)
end, {})

vim.api.nvim_create_user_command("MainSettings", function()
    local menu = {
        "1. Change theme",
        "2. Tree-sitter settings",
        "3. Update plugins",
    }

    vim.ui.select(menu, {
        prompt = "Settings:",
    }, function(choice)
        if choice == nil then
            return
        end

        if choice:match("^1") then
            vim.cmd("ThemePick")
        elseif choice:match("^2") then
            vim.cmd("TSSettings")
        elseif choice:match("^3") then
            vim.cmd("Lazy sync")
        end
    end)
end, {})

vim.api.nvim_create_user_command("AboutNeovim", function()
    about.open()
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