local M = {}

local settings = require("config.buffers.settings")
local enabled = settings.get("auto_save")

local function saveable(buf)
    return enabled
        and vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].modifiable
        and not vim.bo[buf].readonly
        and vim.bo[buf].modified
        and vim.api.nvim_buf_get_name(buf) ~= ""
end

function M.enabled()
    return enabled
end

function M.toggle()
    enabled = not enabled
    settings.set("auto_save", enabled)
    vim.notify("Auto save: " .. (enabled and "enabled" or "disabled"))
end

function M.setup()
    local group = vim.api.nvim_create_augroup("ConfigAutoSave", { clear = true })

    vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "FocusLost" }, {
        group = group,
        callback = function(args)
            if not saveable(args.buf) then
                return
            end

            vim.api.nvim_buf_call(args.buf, function()
                local ok, err = pcall(vim.cmd, "silent update")

                if not ok then
                    vim.notify("Auto save failed: " .. err, vim.log.levels.ERROR)
                end
            end)
        end,
    })
end

return M
