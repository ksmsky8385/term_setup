local function enable_terminal_buffers(plugin_dir)
    local path = plugin_dir .. "/lua/scrollview.lua"
    local lines = vim.fn.readfile(path)
    local patched_comment = "  -- Terminal buffers are supported by this configuration."

    for _, line in ipairs(lines) do
        if line == patched_comment then
            return
        end
    end

    for index = 1, #lines - 4 do
        if
            lines[index] == "  -- Don't show in terminal mode, since the bar won't be properly updated for"
            and lines[index + 1] == "  -- insertions."
            and lines[index + 2] == "  if to_bool(wininfo.terminal) then"
            and lines[index + 3] == "    return false"
            and lines[index + 4] == "  end"
        then
            lines[index] = patched_comment
            for _ = 1, 4 do
                table.remove(lines, index + 1)
            end

            local result = vim.fn.writefile(lines, path)
            assert(result == 0, "Failed to patch nvim-scrollview terminal support")
            return
        end
    end

    error("Unsupported nvim-scrollview version: terminal exclusion block not found")
end

local toggle_state = require("config.toggle_state")
local enabled_on_startup = toggle_state.read("scrollview", false)

return {
    "dstein64/nvim-scrollview",
    lazy = not enabled_on_startup,
    build = function(plugin)
        enable_terminal_buffers(plugin.dir)
    end,
    cmd = {
        "ScrollViewToggle",
        "ScrollViewEnable",
        "ScrollViewDisable",
    },
    keys = {
        {
            "<leader>ms",
            function()
                vim.cmd("ScrollViewToggle")
                local enabled = vim.g.scrollview_enabled == true or vim.g.scrollview_enabled == 1
                toggle_state.write("scrollview", enabled)
            end,
            desc = "Toggle scrollbar",
        },
    },
    config = function()
        require("scrollview").setup({
            on_startup = enabled_on_startup,
            current_only = true,
            floating_windows = true,
        })

        vim.api.nvim_create_autocmd("TextChangedT", {
            group = vim.api.nvim_create_augroup("ScrollViewTerminalRefresh", { clear = true }),
            callback = function()
                require("scrollview").refresh_impl_async()
            end,
            desc = "Refresh scrollbar when terminal output changes",
        })
    end,
}
