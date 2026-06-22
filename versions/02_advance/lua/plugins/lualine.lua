return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        local terminal = require("config.terminal")
        local window_picker = require("config.window_picker")
        local picker_exclude = {
            filetype = {
                "NvimTree",
                "notify",
            },
        }

        local function is_labeled_window(win)
            return window_picker.label_for_window(win, picker_exclude) ~= ""
        end

        local function window_label()
            local current = vim.g.statusline_winid or vim.api.nvim_get_current_win()

            if is_labeled_window(current) then
                return "[" .. window_picker.label_for_window(current, picker_exclude) .. "]"
            end

            return ""
        end

        require("lualine").setup({
            options = {
                theme = "auto",
                section_separators = "",
                component_separators = "",
            },
            sections = {
                lualine_c = {
                    {
                        window_label,
                        on_click = window_picker.focus_statusline_window,
                    },
                    terminal.status_name,
                    {
                        "filename",
                        cond = function()
                            return not terminal.is_status_terminal()
                        end,
                    },
                },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {
                    {
                        window_label,
                        on_click = window_picker.focus_statusline_window,
                    },
                    terminal.status_name,
                    {
                        "filename",
                        cond = function()
                            return not terminal.is_status_terminal()
                        end,
                    },
                },
                lualine_x = { "location" },
                lualine_y = {},
                lualine_z = {},
            },
        })
    end,
}
