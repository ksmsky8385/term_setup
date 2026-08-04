local M = {}

local function current_tab_index()
    local current = vim.api.nvim_get_current_tabpage()

    for index, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        if tabpage == current then
            return index
        end
    end

    return vim.fn.tabpagenr()
end

function M.restore_tabpage(tabpage, win)
    if vim.api.nvim_tabpage_is_valid(tabpage) then
        vim.api.nvim_set_current_tabpage(tabpage)
    end

    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
    end
end

local function tab_prompt(index)
    local total = vim.fn.tabpagenr("$")

    vim.cmd("redraw!")

    if vim.opt.cmdheight._value ~= 0 then
        print(
            string.format(
                "Pick tab T%02d (%d/%d): h/l or arrows, Enter pick window, Esc cancel",
                index - 1,
                index,
                total
            )
        )
    end
end

function M.pick_tab_for_window()
    local tabpages = vim.api.nvim_list_tabpages()

    if #tabpages <= 1 then
        return true
    end

    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local original_win = vim.api.nvim_get_current_win()
    local index = current_tab_index()

    tab_prompt(index)

    while true do
        local ok, input = pcall(vim.fn.getcharstr)

        if not ok then
            M.restore_tabpage(original_tabpage, original_win)
            return false
        end

        local key = vim.fn.keytrans(input or "")

        if input == "\13" or input == "\10" or input == "\r" then
            vim.cmd("redraw")
            return true
        end

        if input == "\27" then
            M.restore_tabpage(original_tabpage, original_win)
            vim.cmd("redraw")
            return false
        end

        if input == "h" or input == "H" or key == "<Left>" then
            index = index - 1

            if index < 1 then
                index = #tabpages
            end
        elseif input == "l" or input == "L" or key == "<Right>" then
            index = index + 1

            if index > #tabpages then
                index = 1
            end
        else
            tab_prompt(index)
            goto continue
        end

        if vim.api.nvim_tabpage_is_valid(tabpages[index]) then
            vim.api.nvim_set_current_tabpage(tabpages[index])
        end

        vim.cmd("redraw!")
        tab_prompt(index)

        ::continue::
    end
end

return M
