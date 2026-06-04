return {
    "42Paris/42header",
    config = function()
        local user = vim.env.FORTYTWO_USER
        local mail = vim.env.FORTYTWO_MAIL

        if user and user ~= "" then
            vim.g.user42 = user
        end

        if mail and mail ~= "" then
            vim.g.mail42 = mail
        end
    end,
}
