local settings = require("config.buffers.settings")

local M = {}

local enabled = settings.get("end_of_buffer_markers")

local function apply()
    local fillchars = vim.opt.fillchars:get()

    fillchars.eob = enabled and "~" or " "
    vim.opt.fillchars = fillchars
end

function M.enabled()
    return enabled
end

function M.toggle()
    enabled = not enabled
    settings.set("end_of_buffer_markers", enabled)
    apply()
    vim.notify("End-of-buffer markers: " .. (enabled and "enabled" or "disabled"))
end

function M.setup()
    apply()
end

return M
