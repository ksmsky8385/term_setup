local state = require("config.buffers.state")
local settings = require("config.buffers.settings")
local visibility = require("config.buffers.window_visibility")

local M = {}

local enabled = settings.get("auto_close")
local previous_by_window = {}

local function has_floating_assignment(buf)
    local ok, floating = pcall(require, "config.floating")

    return ok
        and type(floating.has_assignment) == "function"
        and floating.has_assignment(buf)
end

local function can_close(buf)
    return enabled
        and vim.api.nvim_buf_is_valid(buf)
        and state.movable(buf)
        and visibility.all_visible_count(buf) == 0
        and not has_floating_assignment(buf)
        and state.delete_blocker(buf, false) == nil
end

function M.enabled()
    return enabled
end

function M.toggle()
    enabled = not enabled
    settings.set("auto_close", enabled)
    vim.notify("Auto close buffer: " .. (enabled and "enabled" or "disabled"))
end

function M.setup()
    local group = vim.api.nvim_create_augroup("ConfigAutoCloseBuffer", {
        clear = true,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        callback = function(args)
            local win = vim.api.nvim_get_current_win()

            if
                enabled
                and vim.api.nvim_win_is_valid(win)
                and vim.api.nvim_win_get_buf(win) == args.buf
            then
                previous_by_window[win] = args.buf
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(args)
            local win = vim.api.nvim_get_current_win()
            local previous = previous_by_window[win]

            previous_by_window[win] = nil

            if not previous or previous == args.buf or not state.movable(args.buf) then
                return
            end

            vim.schedule(function()
                if not can_close(previous) then
                    return
                end

                local ok, err = state.delete(previous, false)

                if not ok then
                    state.notify_delete_error(err)
                end
            end)
        end,
    })
end

return M
