local M = {}

local picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
local active_picker = nil

local function is_excluded(win, exclude)
    if not vim.api.nvim_win_is_valid(win) then
        return true
    end

    local config = vim.api.nvim_win_get_config(win)

    if not config.focusable or config.hide or config.external then
        return true
    end

    local buf = vim.api.nvim_win_get_buf(win)

    for option, values in pairs(exclude or {}) do
        local ok, option_value = pcall(vim.api.nvim_get_option_value, option, {
            buf = buf,
        })

        if ok and vim.tbl_contains(values, option_value) then
            return true
        end
    end

    return false
end

function M.selectable_windows(exclude)
    local windows = {}

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if not is_excluded(win, exclude) then
            table.insert(windows, win)
        end
    end

    return windows
end

function M.label_for_window(win, exclude)
    local index = 1

    for _, candidate in ipairs(M.selectable_windows(exclude)) do
        if candidate == win then
            return picker_chars:sub(index, index)
        end

        index = index + 1
    end

    return ""
end

function M.focus_statusline_window()
    local mouse = vim.fn.getmousepos()
    local win = mouse.winid

    if type(win) ~= "number" or win == 0 then
        win = vim.g.statusline_winid
    end

    if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
    end
end

function M.on_picker_statusline_click(win)
    if not active_picker then
        return
    end

    if type(win) ~= "number" or not active_picker.window_map[win] then
        return
    end

    active_picker.selected = win
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
end

local function clear_prompt()
    if vim.opt.cmdheight._value ~= 0 then
        vim.cmd("normal! :")
    end
end

function M.pick_window(exclude)
    local selectable = M.selectable_windows(exclude)

    if #selectable == 0 then
        return -1
    end

    if #selectable == 1 then
        return selectable[1]
    end

    if #picker_chars < #selectable then
        vim.notify(
            string.format("More windows (%d) than picker chars (%d).", #selectable, #picker_chars),
            vim.log.levels.ERROR
        )
        return nil
    end

    local previous = {}
    local char_map = {}
    local window_map = {}
    local laststatus = vim.o.laststatus
    local fillchars = vim.opt.fillchars:get()
    local old_stl = fillchars.stl
    local old_stlnc = fillchars.stlnc

    vim.o.laststatus = 2
    fillchars.stl = nil
    fillchars.stlnc = nil
    vim.opt.fillchars = fillchars
    fillchars.stl = old_stl
    fillchars.stlnc = old_stlnc

    for index, win in ipairs(selectable) do
        local char = picker_chars:sub(index, index)
        local ok_status, statusline = pcall(vim.api.nvim_get_option_value, "statusline", {
            win = win,
        })
        local ok_hl, winhl = pcall(vim.api.nvim_get_option_value, "winhl", {
            win = win,
        })

        previous[win] = {
            statusline = ok_status and statusline or "",
            winhl = ok_hl and winhl or "",
        }
        char_map[char] = win
        window_map[win] = true

        vim.api.nvim_set_option_value(
            "statusline",
            "%" .. win .. "@v:lua.require'config.window_picker'.on_picker_statusline_click@%=" .. char .. "%=%T",
            { win = win }
        )
        vim.api.nvim_set_option_value(
            "winhl",
            "StatusLine:NvimTreeWindowPicker,StatusLineNC:NvimTreeWindowPicker",
            { win = win }
        )
    end

    active_picker = {
        selected = nil,
        window_map = window_map,
    }

    vim.cmd("redraw")

    if vim.opt.cmdheight._value ~= 0 then
        print("Pick window: ")
    end

    local picked = nil

    while true do
        local ok, input = pcall(vim.fn.getcharstr)

        if not ok then
            break
        end

        if active_picker and active_picker.selected then
            picked = active_picker.selected
            break
        end

        local translated = vim.fn.keytrans(input or "")

        if translated:find("Mouse", 1, true) then
            local mouse = vim.fn.getmousepos()
            local win = mouse.winid

            if type(win) == "number" and window_map[win] then
                picked = win
                break
            end
        end

        input = (input or ""):upper()

        if input == "\13" or input == "\10" then
            if active_picker and active_picker.selected then
                picked = active_picker.selected
            end
            break
        end

        if input == "\27" then
            break
        end

        if char_map[input] then
            picked = char_map[input]
            break
        end
    end

    active_picker = nil
    clear_prompt()

    for win, options in pairs(previous) do
        if vim.api.nvim_win_is_valid(win) then
            for option, value in pairs(options) do
                vim.api.nvim_set_option_value(option, value, { win = win })
            end
        end
    end

    vim.o.laststatus = laststatus
    vim.opt.fillchars = fillchars
    vim.cmd("redraw")

    return picked
end

return M
