return {
    "42Paris/42header",
    config = function()
        local user = vim.env.NAME
        local mail = vim.env.MAIL
        local function apply_keymaps()
            for _, mode in ipairs({ "n", "x", "s", "o" }) do
                pcall(vim.keymap.del, mode, "<F1>")
            end

            vim.keymap.set("i", "<F1>", "<Cmd>Stdheader<CR>", {
                desc = "Insert/update 42 header",
                silent = true,
            })
        end

        if user and user ~= "" then
            vim.g.user42 = user
        end

        if mail and mail ~= "" then
            vim.g.mail42 = mail
        end

        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = apply_keymaps,
        })
    end,
}
