return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
        require("nvim-autopairs").setup({
            check_ts = true,
        })

        local closers = {
            [")"] = true,
            ["]"] = true,
            ["}"] = true,
            [">"] = true,
            ['"'] = true,
            ["'"] = true,
            ["`"] = true,
        }

        local function jump_out_of_pair()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local col = cursor[2]
            local line = vim.api.nvim_get_current_line()

            for index = col + 1, #line do
                local char = line:sub(index, index)

                if closers[char] then
                    return string.rep("<Right>", index - col)
                end
            end

            return ""
        end

        vim.keymap.set("i", "<C-l>", jump_out_of_pair, {
            expr = true,
            noremap = true,
            silent = true,
            desc = "Jump out of pair",
        })
    end,
}
