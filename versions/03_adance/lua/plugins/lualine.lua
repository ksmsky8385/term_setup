return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        local picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

        local function is_labeled_window(win)
            if not vim.api.nvim_win_is_valid(win) then
                return false
            end

            local config = vim.api.nvim_win_get_config(win)

            if not config.focusable or config.hide or config.external then
                return false
            end

            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            return filetype ~= "NvimTree"
                and filetype ~= "notify"
        end

        local function window_label()
            local current = vim.g.statusline_winid or vim.api.nvim_get_current_win()
            local index = 1

            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_labeled_window(win) then
                    if win == current then
                        return "[" .. picker_chars:sub(index, index) .. "]"
                    end

                    index = index + 1
                end
            end

            return ""
        end

        require("lualine").setup({
            options = {
                theme = "auto",
                section_separators = "",
                component_separators = "",
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { window_label, "filename" },
                lualine_x = { "location" },
                lualine_y = {},
                lualine_z = {},
            },
        })
    end,
}
