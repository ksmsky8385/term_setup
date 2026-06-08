local M = {}

local function valid_listed_buffer(buf)
    return buf
        and vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
end

local function listed_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if valid_listed_buffer(buf) then
            table.insert(buffers, buf)
        end
    end

    return buffers
end

local function buffer_name(buf)
    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":t")
end

local hidden_replacement_buffer
local movable_buffer
local buffer_terminal_kind
local window_picker_exclude = {
    filetype = {
        "NvimTree",
        "notify",
        "FloatingTerminal",
    },
}

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function delete_blocker(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end

    if vim.bo[buf].modified and not force then
        return "Buffer has unsaved changes: " .. buffer_name(buf)
    end

    if vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) and not force then
        return "Terminal is still running: " .. buffer_name(buf) .. ". Use D/O to force."
    end

    return nil
end

local function delete_buffer(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return true
    end

    local blocker = delete_blocker(buf, force)

    if blocker then
        return false, blocker
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
        force = force,
    })

    if not ok then
        return false, "Failed to delete buffer: " .. err
    end

    return true
end

local function visible_tab_labels_by_buffer()
    local ok_picker, window_picker = pcall(require, "config.window_picker")
    local labels = {}
    local max_width = 0
    local show_tab_label = vim.fn.tabpagenr("$") > 1
    if not ok_picker then
        return labels, max_width
    end

    for tabnr, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        local tab_labels = {}
        local previous_tabpage = vim.api.nvim_get_current_tabpage()

        vim.api.nvim_set_current_tabpage(tabpage)

        for _, win in ipairs(window_picker.selectable_windows(window_picker_exclude)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local window_label = window_picker.label_for_window(win, window_picker_exclude)

            if valid_listed_buffer(buf) and window_label ~= "" then
                tab_labels[buf] = tab_labels[buf] or {}
                table.insert(tab_labels[buf], window_label)
            end
        end

        vim.api.nvim_set_current_tabpage(previous_tabpage)

        for buf, window_labels in pairs(tab_labels) do
            local tab_label = show_tab_label
                    and string.format("T%02d", tabnr - 1)
                or ""
            local label = "[" .. table.concat(window_labels, ",") .. "]"

            if tab_label ~= "" then
                label = "[" .. tab_label .. "]" .. label
            end

            labels[buf] = labels[buf] or {}
            table.insert(labels[buf], label)
        end
    end

    for buf, buf_labels in pairs(labels) do
        labels[buf] = table.concat(buf_labels, " ")
        max_width = math.max(max_width, #labels[buf])
    end

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal then
        for _, buf in ipairs(listed_buffers()) do
            if terminal.is_float_terminal(buf) then
                labels[buf] = "Floating"
                max_width = math.max(max_width, #labels[buf])
            end
        end
    end

    return labels, max_width
end

local function buffer_entry_maker(opts)
    local make_entry = require("telescope.make_entry")
    local base_maker = make_entry.gen_from_buffer(opts)
    local labels, label_width = visible_tab_labels_by_buffer()

    return function(entry)
        local made = base_maker(entry)

        if not made then
            return made
        end

        made.sort_score = entry.sort_score

        if label_width == 0 then
            return made
        end

        local base_display = made.display

        made.display = function(display_entry)
            local display, highlights

            if type(base_display) == "function" then
                display, highlights = base_display(display_entry)
            else
                display = base_display
            end

            local label = labels[display_entry.bufnr]
            local prefix = string.rep(" ", label_width + 3)

            if label then
                prefix = string.format("%-" .. (label_width + 2) .. "s ", "[" .. label .. "]")
            end

            highlights = highlights or {}

            if label then
                table.insert(highlights, 1, {
                    { 0, #prefix - 1 },
                    "TelescopeResultsIdentifier",
                })
            end

            for _, highlight in ipairs(highlights) do
                if highlight[1][1] ~= 0 or highlight[1][2] ~= #prefix - 1 then
                    highlight[1][1] = highlight[1][1] + #prefix
                    highlight[1][2] = highlight[1][2] + #prefix
                end
            end

            return prefix .. display, highlights
        end

        return made
    end
end

local function buffer_sorter(opts)
    local sorters = require("telescope.sorters")
    local generic = require("telescope.config").values.generic_sorter(opts)

    return sorters.Sorter:new({
        scoring_function = function(_, prompt, line, entry, cb_add, cb_filter)
            if prompt == "" then
                return entry.sort_score or 1
            end

            return generic:scoring_function(prompt, line, entry, cb_add, cb_filter)
        end,
        highlighter = function(_, prompt, display)
            if generic.highlighter then
                return generic:highlighter(prompt, display)
            end

            return {}
        end,
    })
end

local function selected_buffer(prompt_bufnr)
    local ok_state, action_state = pcall(require, "telescope.actions.state")

    if not ok_state then
        return nil
    end

    local selection = action_state.get_selected_entry(prompt_bufnr)

    if not selection then
        return nil
    end

    return selection.bufnr
end

local function close_picker(prompt_bufnr)
    local ok_actions, actions = pcall(require, "telescope.actions")

    if ok_actions then
        actions.close(prompt_bufnr)
    end
end

local function confirm_action(message)
    vim.api.nvim_echo({
        { message .. " Press Enter to confirm, Esc to cancel.", "WarningMsg" },
    }, false, {})

    local ok, input = pcall(vim.fn.getcharstr)

    vim.cmd("redraw")
    vim.api.nvim_echo({}, false, {})

    if not ok then
        return false
    end

    return input == "\13" or input == "\10" or input == "\r"
end

local function notify_delete_error(err)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

local function visible_windows_for_buffer(buf)
    local windows = {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return windows
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            table.insert(windows, win)
        end
    end

    return windows
end

local function all_visible_windows_for_buffer(buf)
    local windows = {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return windows
    end

    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
                table.insert(windows, win)
            end
        end
    end

    return windows
end

local function all_visible_window_count(buf)
    return #all_visible_windows_for_buffer(buf)
end

buffer_terminal_kind = function(buf)
    local ok_terminal, terminal = pcall(require, "config.terminal")

    if not ok_terminal then
        return nil
    end

    if terminal.is_float_terminal(buf) then
        return "float"
    end

    if vim.bo[buf].buftype == "terminal" then
        return "buffer"
    end

    return nil
end

movable_buffer = function(buf)
    if not valid_listed_buffer(buf) then
        return false
    end

    local filetype = vim.bo[buf].filetype

    if filetype == "NvimTree" or filetype == "alpha" or filetype == "notify" then
        return false
    end

    local buftype = vim.bo[buf].buftype

    if buftype == "" then
        return true
    end

    return buffer_terminal_kind(buf) == "buffer"
end

hidden_replacement_buffer = function(current)
    local candidates = {}

    for _, buf in ipairs(listed_buffers()) do
        if buf ~= current and movable_buffer(buf) and all_visible_window_count(buf) == 0 then
            table.insert(candidates, buf)
        end
    end

    table.sort(candidates, function(a, b)
        return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
    end)

    return candidates[1]
end

local function can_delete_unique_window_buffer(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if not movable_buffer(buf) then
        return false
    end

    if all_visible_window_count(buf) ~= 1 then
        return false
    end

    return delete_blocker(buf, force) == nil
end

local function window_for_buffer(buf)
    return visible_windows_for_buffer(buf)[1]
end

local function any_window_for_buffer(buf)
    return all_visible_windows_for_buffer(buf)[1]
end

local function first_selectable_window_for_buffer(buf)
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if ok_picker then
        for _, win in ipairs(window_picker.selectable_windows(window_picker_exclude)) do
            if vim.api.nvim_win_get_buf(win) == buf then
                return win
            end
        end
    end

    return window_for_buffer(buf)
end

local function fallback_buffer_for_displaced(buf)
    return vim.api.nvim_create_buf(true, false)
end

local function fallback_buffer_for_deleted()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buflisted = false

    return buf
end

local function target_window_count(tabpage)
    local count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if
                filetype ~= "FloatingTerminal"
                and filetype ~= "NvimTree"
                and filetype ~= "TelescopePrompt"
                and filetype ~= "TelescopeResults"
                and filetype ~= "TelescopePreview"
                and filetype ~= "notify"
            then
                count = count + 1
            end
        end
    end

    return count
end

local function tabpage_for_window(target_win)
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if win == target_win then
                return tabpage
            end
        end
    end

    return nil
end

local function fallback_for_cleared_window(win, original_buf)
    local fallback
    local tabpage = tabpage_for_window(win)

    if tabpage and target_window_count(tabpage) == 1 then
        pcall(vim.api.nvim_set_current_win, win)

        if pcall(vim.cmd, "DashboardHome") and vim.api.nvim_win_is_valid(win) then
            fallback = vim.api.nvim_win_get_buf(win)
        end
    end

    if not fallback or fallback == original_buf or not vim.api.nvim_buf_is_valid(fallback) then
        fallback = fallback_buffer_for_deleted()
        vim.api.nvim_win_set_buf(win, fallback)
    end

    return fallback
end

local function clear_windows_showing_buffer(buf)
    local cleared = {}
    local current_win = vim.api.nvim_get_current_win()

    for _, win in ipairs(all_visible_windows_for_buffer(buf)) do
        if vim.api.nvim_win_is_valid(win) then
            local fallback = fallback_for_cleared_window(win, buf)

            table.insert(cleared, {
                win = win,
                fallback = fallback,
            })
        end
    end

    if vim.api.nvim_win_is_valid(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    return cleared
end

local function restore_windows_after_failed_delete(buf, cleared)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    for _, entry in ipairs(cleared) do
        if vim.api.nvim_win_is_valid(entry.win) then
            pcall(vim.api.nvim_win_set_buf, entry.win, buf)
        end

        if vim.api.nvim_buf_is_valid(entry.fallback) then
            pcall(vim.api.nvim_buf_delete, entry.fallback, {
                force = true,
            })
        end
    end
end

local function clear_listed_windows_except(keep_windows)
    local cleared = {}
    local keep = {}
    local ignored_filetypes = {
        FloatingTerminal = true,
        NvimTree = true,
        notify = true,
    }

    for _, win in ipairs(keep_windows or {}) do
        keep[win] = true
    end

    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if vim.api.nvim_win_is_valid(win) and not keep[win] then
                local original = vim.api.nvim_win_get_buf(win)

                if
                    valid_listed_buffer(original)
                    and not ignored_filetypes[vim.bo[original].filetype]
                then
                    local fallback = fallback_buffer_for_deleted()

                    vim.api.nvim_win_set_buf(win, fallback)
                    table.insert(cleared, {
                        win = win,
                        original = original,
                        fallback = fallback,
                    })
                end
            end
        end
    end

    return cleared
end

local function restore_cleared_windows(cleared)
    for _, entry in ipairs(cleared) do
        if
            vim.api.nvim_win_is_valid(entry.win)
            and vim.api.nvim_buf_is_valid(entry.original)
        then
            pcall(vim.api.nvim_win_set_buf, entry.win, entry.original)
        end

        if vim.api.nvim_buf_is_valid(entry.fallback) then
            pcall(vim.api.nvim_buf_delete, entry.fallback, {
                force = true,
            })
        end
    end
end

local function current_tab_index()
    local current = vim.api.nvim_get_current_tabpage()

    for index, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        if tabpage == current then
            return index
        end
    end

    return vim.fn.tabpagenr()
end

local function restore_tabpage(tabpage, win)
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

local function pick_tab_for_window()
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
            restore_tabpage(original_tabpage, original_win)
            return false
        end

        local key = vim.fn.keytrans(input or "")

        if input == "\13" or input == "\10" or input == "\r" then
            vim.cmd("redraw")
            return true
        end

        if input == "\27" then
            restore_tabpage(original_tabpage, original_win)
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

local function open_selected(prompt_bufnr)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    local existing_win = first_selectable_window_for_buffer(buf)

    close_picker(prompt_bufnr)

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal and terminal.is_float_terminal(buf) then
        terminal.show_float_terminal(buf)
        return
    end

    if existing_win and vim.api.nvim_win_is_valid(existing_win) then
        vim.api.nvim_set_current_win(existing_win)
        return
    end

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            vim.api.nvim_win_set_buf(0, buf)
            return
        end

        local target_win = window_picker.pick_window(window_picker_exclude)

        if not target_win or target_win == -1 then
            M.pick()
            return
        end

        if M.move_buffer_to_window(buf, target_win) then
            vim.api.nvim_set_current_win(target_win)
        end
    end)
end

local function delete_selected(prompt_bufnr, force)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    if
        not confirm_action(
            string.format(
                "%s buffer %d (%s)?",
                force and "Force delete" or "Delete",
                buf,
                buffer_name(buf)
            )
        )
    then
        return
    end

    local cleared_windows = clear_windows_showing_buffer(buf)

    local ok, err = delete_buffer(buf, force)

    if not ok then
        restore_windows_after_failed_delete(buf, cleared_windows)
        notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(M.pick)
end

local function delete_others_except(buf, force, opts)
    opts = opts or {}

    local blockers = {}

    for _, listed_buf in ipairs(listed_buffers()) do
        if listed_buf ~= buf then
            local blocker = delete_blocker(listed_buf, force)

            if blocker then
                table.insert(blockers, blocker)
            end
        end
    end

    if #blockers > 0 then
        return false, table.concat(blockers, "\n")
    end

    local cleared_windows = clear_listed_windows_except(opts.keep_windows)

    for _, listed_buf in ipairs(listed_buffers()) do
        if listed_buf ~= buf then
            local ok, err = delete_buffer(listed_buf, force)

            if not ok then
                restore_cleared_windows(cleared_windows)
                return false, err
            end
        end
    end

    return true
end

local function keep_selected_only(prompt_bufnr, force)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    if
        not confirm_action(
            string.format(
                "%s every buffer except %d (%s)?",
                force and "Force delete" or "Delete",
                buf,
                buffer_name(buf)
            )
        )
    then
        return
    end

    local ok, err = delete_others_except(buf, force, {
        keep_windows = all_visible_windows_for_buffer(buf),
    })

    if not ok then
        notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(function()
        M.pick(buf)
    end)
end

local function move_selected(prompt_bufnr)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local original_win = vim.api.nvim_get_current_win()

    close_picker(prompt_bufnr)

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            return
        end

        if not pick_tab_for_window() then
            M.pick(buf)
            return
        end

        local target_win = window_picker.pick_window(window_picker_exclude)

        if not target_win or target_win == -1 then
            restore_tabpage(original_tabpage, original_win)
            M.pick(buf)
            return
        end

        M.move_buffer_to_window(buf, target_win)
    end)
end

local function split_selected(prompt_bufnr, split_cmd)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local original_win = vim.api.nvim_get_current_win()

    close_picker(prompt_bufnr)

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            return
        end

        if not pick_tab_for_window() then
            M.pick(buf)
            return
        end

        local target_win = window_picker.pick_window(window_picker_exclude)

        if not target_win or target_win == -1 then
            restore_tabpage(original_tabpage, original_win)
            M.pick(buf)
            return
        end

        M.open_buffer_in_split(buf, target_win, split_cmd)
    end)
end

local function open_in_window_selected(prompt_bufnr)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    if not movable_buffer(buf) then
        vim.notify("Buffer can't be opened in window", vim.log.levels.WARN)
        return
    end

    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local original_win = vim.api.nvim_get_current_win()

    close_picker(prompt_bufnr)

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            return
        end

        if not pick_tab_for_window() then
            M.pick(buf)
            return
        end

        local target_win = window_picker.pick_window(window_picker_exclude)

        if not target_win or target_win == -1 then
            restore_tabpage(original_tabpage, original_win)
            M.pick(buf)
            return
        end

        M.open_buffer_in_window(buf, target_win)
    end)
end

local function buffer_picker(initial_buf)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    local bufnrs = vim.tbl_filter(function(buf)
        return valid_listed_buffer(buf)
    end, vim.api.nvim_list_bufs())

    if not next(bufnrs) then
        vim.notify("No buffers found", vim.log.levels.INFO)
        return
    end

    table.sort(bufnrs, function(a, b)
        local a_float = buffer_terminal_kind(a) == "float"
        local b_float = buffer_terminal_kind(b) == "float"

        if a_float ~= b_float then
            return a_float
        end

        return a < b
    end)

    local buffers = {}
    local default_selection_index = nil
    local max_bufnr = math.max(unpack(bufnrs))
    local opts = {
        bufnr_width = #tostring(max_bufnr),
        initial_mode = "normal",
        sort_mru = true,
        ignore_current_buffer = false,
    }

    for index, buf in ipairs(bufnrs) do
        local sort_score = #bufnrs - index + 1

        if buf == initial_buf then
            default_selection_index = sort_score
        end

        table.insert(buffers, {
            bufnr = buf,
            flag = buf == vim.fn.bufnr("") and "%" or (buf == vim.fn.bufnr("#") and "#" or " "),
            info = vim.fn.getbufinfo(buf)[1],
            sort_score = sort_score,
        })
    end

    pickers.new(opts, {
        prompt_title = "Buffers",
        results_title = "Enter open | w window | m move | s/v split | d/D delete | o/O keep only",
        default_selection_index = default_selection_index,
        finder = finders.new_table({
            results = buffers,
            entry_maker = buffer_entry_maker(opts),
        }),
        previewer = conf.grep_previewer(opts),
        sorter = buffer_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            map("i", "<CR>", function()
                open_selected(prompt_bufnr)
            end)

            map("n", "<CR>", function()
                open_selected(prompt_bufnr)
            end)

            map("n", "d", function()
                delete_selected(prompt_bufnr, false)
            end)

            map("n", "D", function()
                delete_selected(prompt_bufnr, true)
            end)

            map("n", "o", function()
                keep_selected_only(prompt_bufnr, false)
            end)

            map("n", "O", function()
                keep_selected_only(prompt_bufnr, true)
            end)

            map("n", "w", function()
                open_in_window_selected(prompt_bufnr)
            end)

            map("n", "m", function()
                move_selected(prompt_bufnr)
            end)

            map("n", "s", function()
                split_selected(prompt_bufnr, "rightbelow split")
            end)

            map("n", "v", function()
                split_selected(prompt_bufnr, "rightbelow vsplit")
            end)

            return true
        end,
    }):find()
end

function M.pick(initial_buf)
    local ok = pcall(require, "telescope.pickers")

    if ok then
        buffer_picker(initial_buf)
        return
    end

    vim.cmd("buffers")
end

function M.pick_current()
    local current = vim.api.nvim_get_current_buf()

    if valid_listed_buffer(current) then
        M.pick(current)
        return
    end

    M.pick()
end

function M.pick_tab_for_window()
    return pick_tab_for_window()
end

function M.next()
    local ok = pcall(vim.cmd, "bnext")

    if not ok then
        vim.notify("No next buffer", vim.log.levels.INFO)
    end
end

function M.previous()
    local ok = pcall(vim.cmd, "bprevious")

    if not ok then
        vim.notify("No previous buffer", vim.log.levels.INFO)
    end
end

function M.delete_current(force)
    local current = vim.api.nvim_get_current_buf()

    if all_visible_window_count(current) > 1 then
        local current_win = vim.api.nvim_get_current_win()

        fallback_for_cleared_window(current_win, current)

        if vim.api.nvim_win_is_valid(current_win) then
            pcall(vim.api.nvim_set_current_win, current_win)
        end

        return true
    end

    local blocker = delete_blocker(current, force)

    if blocker then
        notify_delete_error(blocker)
        return false
    end

    local cleared_windows = clear_windows_showing_buffer(current)

    local ok, err = delete_buffer(current, force)

    if not ok then
        restore_windows_after_failed_delete(current, cleared_windows)
        notify_delete_error(err)
    end

    return ok
end

function M.delete_current_to_hidden(force)
    local current = vim.api.nvim_get_current_buf()
    local replacement = hidden_replacement_buffer(current)

    if not replacement then
        return nil
    end

    local blocker = delete_blocker(current, force)

    if blocker then
        notify_delete_error(blocker)
        return false
    end

    vim.api.nvim_win_set_buf(0, replacement)

    local ok, err = delete_buffer(current, force)

    if not ok then
        notify_delete_error(err)
    end

    return ok
end

local function move_buffer_between_windows(buf, source_win, target_win)
    if not movable_buffer(buf) then
        vim.notify("Buffer can't be moved", vim.log.levels.WARN)
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    local target_buf = vim.api.nvim_win_get_buf(target_win)

    if source_win and source_win == target_win then
        return true
    end

    if source_win and vim.api.nvim_win_is_valid(source_win) then
        if movable_buffer(target_buf) then
            vim.api.nvim_win_set_buf(source_win, target_buf)
        else
            vim.api.nvim_win_set_buf(source_win, fallback_buffer_for_displaced(target_buf))
        end
    end

    vim.api.nvim_win_set_buf(target_win, buf)

    return true
end

function M.move_buffer_to_window(buf, target_win)
    return move_buffer_between_windows(buf, any_window_for_buffer(buf), target_win)
end

function M.move_current_to_window()
    local buf = vim.api.nvim_get_current_buf()
    local source_win = vim.api.nvim_get_current_win()
    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if not ok_picker then
        return false
    end

    if not pick_tab_for_window() then
        return false
    end

    local target_win = window_picker.pick_window(window_picker_exclude)

    if not target_win or target_win == -1 then
        restore_tabpage(original_tabpage, source_win)
        return false
    end

    return move_buffer_between_windows(buf, source_win, target_win)
end

function M.open_buffer_in_window(buf, target_win, opts)
    opts = opts or {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    local old_buf = vim.api.nvim_win_get_buf(target_win)

    if old_buf == buf then
        return true
    end

    local old_visible_count = all_visible_window_count(old_buf)
    local delete_old = opts.delete_old_if_safe
        and old_visible_count == 1
        and movable_buffer(old_buf)

    if delete_old then
        local can_delete = can_delete_unique_window_buffer(old_buf, opts.force)

        if not can_delete then
            local blocker = delete_blocker(old_buf, opts.force)

            if blocker then
                vim.notify(blocker, vim.log.levels.WARN)
            end
        end

        vim.api.nvim_win_set_buf(target_win, buf)

        if can_delete then
            local ok, err = delete_buffer(old_buf, opts.force)

            if not ok then
                notify_delete_error(err)
            end
        end

        return true
    end

    vim.api.nvim_win_set_buf(target_win, buf)

    return true
end

function M.open_buffer_in_split(buf, target_win, split_cmd)
    if not movable_buffer(buf) then
        vim.notify("Buffer can't be opened in split", vim.log.levels.WARN)
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    vim.api.nvim_set_current_win(target_win)

    local ok, err = pcall(vim.cmd, split_cmd)

    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    vim.api.nvim_win_set_buf(0, buf)

    return true
end

function M.delete_others(force)
    local current = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    local ok, err = delete_others_except(current, force, {
        keep_windows = { current_win },
    })

    if not ok then
        notify_delete_error(err)
    end

    return ok
end

return M
