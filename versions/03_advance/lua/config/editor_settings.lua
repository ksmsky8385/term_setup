local state = require("config.toggle_state")
local M = {}

M.options = {
    { name = "autopairs", label = "Auto pairing" },
    { name = "line_numbers", label = "Line numbers", choices = { "absolute", "relative", "hybrid", "off" } },
    { name = "wrap", label = "Wrap long lines" },
    { name = "linebreak", label = "Wrap at word boundaries (requires wrap)" },
    { name = "breakindent", label = "Indent wrapped lines (requires wrap)" },
    { name = "cursorline", label = "Highlight cursor line" },
    { name = "cursorcolumn", label = "Highlight cursor column" },
    { name = "list", label = "Show whitespace" },
    { name = "spell", label = "Spell checking (spelllang)" },
}

function M.get(name)
    return state.read("editor_" .. name)
end

local function apply_window(win)
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "" or vim.b[buf].pending_terminal_restore
        or vim.api.nvim_win_get_config(win).relative ~= ""
        or vim.wo[win].previewwindow then
        return
    end

    local mode = M.get("line_numbers")
    vim.wo[win].number = mode == "absolute" or mode == "hybrid"
    vim.wo[win].relativenumber = mode == "relative" or mode == "hybrid"
    for _, option in ipairs(M.options) do
        if option.name ~= "autopairs" and option.name ~= "line_numbers" then
            vim.wo[win][option.name] = M.get(option.name)
        end
    end
end

function M.apply_autopairs()
    -- Do not force-load the InsertEnter plugin when opening Settings.
    local autopairs = package.loaded["nvim-autopairs"]
    if autopairs then
        if M.get("autopairs") then
            autopairs.enable()
        else
            autopairs.disable()
        end
    end
end

function M.cycle(name)
    for _, option in ipairs(M.options) do
        if option.name == name then
            local value = M.get(name)
            if option.choices then
                for index, choice in ipairs(option.choices) do
                    if choice == value then
                        value = option.choices[index % #option.choices + 1]
                        break
                    end
                end
            else
                value = not value
            end
            state.write("editor_" .. name, value)
            if name == "autopairs" then
                M.apply_autopairs()
            else
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    apply_window(win)
                end
            end
            return
        end
    end
    error("Unknown editor setting: " .. tostring(name))
end

function M.setup()
    local group = vim.api.nvim_create_augroup("EditorSettings", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "FileType" }, {
        group = group,
        callback = function()
            -- Run after filetype/plugin window initialization.
            vim.schedule(function()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    apply_window(win)
                end
            end)
        end,
    })
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        apply_window(win)
    end
end

return M
