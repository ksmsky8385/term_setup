return {
    "lewis6991/gitsigns.nvim",
    event = {
        "BufReadPre",
        "BufNewFile",
    },
    config = function()
        local gitsigns = require("gitsigns")

        gitsigns.setup({
            numhl = true,
            signcolumn = true,
            current_line_blame = false,
            on_attach = function(bufnr)
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, {
                        buffer = bufnr,
                        noremap = true,
                        silent = true,
                        desc = desc,
                    })
                end

                map("n", "]c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({
                            "]c",
                            bang = true,
                        })
                        return
                    end

                    gitsigns.nav_hunk("next")
                end, "Next git hunk")

                map("n", "[c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({
                            "[c",
                            bang = true,
                        })
                        return
                    end

                    gitsigns.nav_hunk("prev")
                end, "Previous git hunk")

                map("n", "<leader>gp", gitsigns.preview_hunk, "Preview git hunk")
                map("n", "<leader>gb", gitsigns.blame_line, "Blame current line")
                map("n", "<leader>gr", gitsigns.reset_hunk, "Reset git hunk")
                map("v", "<leader>gr", function()
                    gitsigns.reset_hunk({
                        vim.fn.line("."),
                        vim.fn.line("v"),
                    })
                end, "Reset selected git hunk")
            end,
        })
    end,
}
