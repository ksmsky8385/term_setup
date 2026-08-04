local M = {}

function M.change(path, opts)
    opts = opts or {}
    path = vim.fs.normalize(vim.fn.expand(path))

    if vim.fn.isdirectory(path) == 0 then
        vim.notify("Directory not found: " .. path, vim.log.levels.ERROR)
        return false
    end

    vim.cmd("cd " .. vim.fn.fnameescape(path))
    vim.g.current_workspace_root = vim.fn.getcwd()

    vim.api.nvim_exec_autocmds("User", {
        pattern = "WorkspaceChanged",
        data = {
            root = vim.g.current_workspace_root,
        },
    })

    if opts.notify ~= false then
        vim.notify(" -> Workspace changed: " .. vim.g.current_workspace_root)
    end

    return true
end

return M
