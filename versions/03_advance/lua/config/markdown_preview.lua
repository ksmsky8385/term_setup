local M = {}

function M.repair_on_start(plugin)
    local app = plugin.dir .. "/app"
    -- Fresh installs already run Lazy's build hook. Repair existing copies only.
    if vim.fn.filereadable(app .. "/package.json") ~= 1 then
        return
    end
    local manifest = vim.json.decode(table.concat(vim.fn.readfile(app .. "/package.json"), "\n"))
    for name in pairs(manifest.dependencies or {}) do
        if vim.fn.isdirectory(app .. "/node_modules/" .. name) ~= 1 then
            vim.api.nvim_create_autocmd("VimEnter", {
                once = true,
                callback = function()
                    vim.schedule(function()
                        require("lazy").build({ plugins = { plugin.name } })
                    end)
                end,
            })
            return
        end
    end
end

return M
