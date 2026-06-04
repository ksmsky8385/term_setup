return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },

    config = function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")

        local function is_nvim_tree()
            return vim.bo.filetype == "NvimTree"
        end

        local function search_current_word()
            if is_nvim_tree() then
                return
            end

            builtin.live_grep({
                default_text = vim.fn.expand("<cword>"),
            })
        end

        local function visual_selection()
            local register = "v"
            local old_value = vim.fn.getreg(register)
            local old_type = vim.fn.getregtype(register)

            vim.cmd([[noautocmd normal! "vy]])

            local text = vim.fn.getreg(register)

            vim.fn.setreg(register, old_value, old_type)

            return text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        end

        local function search_visual_selection()
            if is_nvim_tree() then
                return
            end

            local text = visual_selection()

            if text == "" then
                return
            end

            builtin.live_grep({
                default_text = text,
            })
        end

        telescope.setup({})

        vim.keymap.set("n", "<leader>ff", builtin.find_files, {
            desc = "Find files",
        })

        vim.keymap.set("n", "<leader>fg", builtin.live_grep, {
            desc = "Live grep",
        })

        vim.keymap.set("n", "<leader>sw", search_current_word, {
            desc = "Search current word",
        })

        vim.keymap.set("v", "<leader>ss", search_visual_selection, {
            desc = "Search selected text",
        })

        vim.keymap.set("n", "<leader>fb", builtin.buffers, {
            desc = "Find buffers",
        })

        vim.keymap.set("n", "<leader>fh", builtin.help_tags, {
            desc = "Help tags",
        })
    end,
}
