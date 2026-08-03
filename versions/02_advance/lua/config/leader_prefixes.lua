local M = {}

local prefixes = {
    "a",
    "b",
    "c",
    "d",
    "f",
    "g",
    "m",
    "p",
    "P",
    "r",
    "s",
    "t",
    "w",
    "<Tab>",
}

function M.setup()
    -- Keep an incomplete multi-key leader mapping from falling through to the
    -- key's built-in Normal/Visual mode action when 'timeoutlen' expires.
    for _, prefix in ipairs(prefixes) do
        vim.keymap.set({ "n", "v" }, "<leader>" .. prefix, "<Nop>", {
            desc = "Leader prefix",
            silent = true,
        })
    end
end

return M
