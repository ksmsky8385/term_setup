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

local function replacement_buffer(current)
    local alternate = vim.fn.bufnr("#")

    if alternate ~= current and valid_listed_buffer(alternate) then
        return alternate
    end

    for _, buf in ipairs(listed_buffers()) do
        if buf ~= current then
            return buf
        end
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

local function window_labels_by_buffer()
    local ok_picker, window_picker = pcall(require, "config.window_picker")
    local labels = {}
    local max_width = 0
    local exclude = {
        filetype = {
            "NvimTree",
            "notify",
        },
    }

    if not ok_picker then
        return labels, max_width
    end

    for _, win in ipairs(window_picker.selectable_windows(exclude)) do
        local buf = vim.api.nvim_win_get_buf(win)

        if valid_listed_buffer(buf) then
            local label = window_picker.label_for_window(win, exclude)

            if label ~= "" then
                labels[buf] = labels[buf] or {}
                table.insert(labels[buf], label)
            end
        end
    end

    for buf, buf_labels in pairs(labels) do
        labels[buf] = table.concat(buf_labels, ",")
        max_width = math.max(max_width, #labels[buf])
    end

    return labels, max_width
end

local function buffer_entry_maker(opts)
    local make_entry = require("telescope.make_entry")
    local base_maker = make_entry.gen_from_buffer(opts)
    local labels, label_width = window_labels_by_buffer()

    return function(entry)
        local made = base_maker(entry)

        if not made or label_width == 0 then
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

    if not ok then
        return false
    end

    return input == "\13" or input == "\10" or input == "\r"
end

local function focus_buffer(buf)
    if valid_listed_buffer(buf) then
        vim.api.nvim_win_set_buf(0, buf)
    end
end

local function notify_delete_error(err)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
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

    local current = vim.api.nvim_get_current_buf()

    if buf == current then
        local replacement = replacement_buffer(current)

        if replacement then
            vim.api.nvim_win_set_buf(0, replacement)
        else
            vim.cmd("enew")
        end
    end

    local ok, err = delete_buffer(buf, force)

    if not ok then
        notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(M.pick)
end

local function delete_others_except(buf, force)
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

    for _, listed_buf in ipairs(listed_buffers()) do
        if listed_buf ~= buf then
            local ok, err = delete_buffer(listed_buf, force)

            if not ok then
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

    local ok, err = delete_others_except(buf, force)

    if not ok then
        notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    focus_buffer(buf)
end

local function buffer_picker()
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
        return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
    end)

    local buffers = {}
    local max_bufnr = math.max(unpack(bufnrs))
    local opts = {
        bufnr_width = #tostring(max_bufnr),
        initial_mode = "normal",
        sort_mru = true,
        ignore_current_buffer = false,
    }

    for _, buf in ipairs(bufnrs) do
        table.insert(buffers, {
            bufnr = buf,
            flag = buf == vim.fn.bufnr("") and "%" or (buf == vim.fn.bufnr("#") and "#" or " "),
            info = vim.fn.getbufinfo(buf)[1],
        })
    end

    pickers.new(opts, {
        prompt_title = "Buffers",
        results_title = "Enter open | d/D delete | o/O keep only | destructive actions ask Enter",
        finder = finders.new_table({
            results = buffers,
            entry_maker = buffer_entry_maker(opts),
        }),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
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

            return true
        end,
    }):find()
end

function M.pick()
    local ok = pcall(require, "telescope.pickers")

    if ok then
        buffer_picker()
        return
    end

    vim.cmd("buffers")
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
    local blocker = delete_blocker(current, force)

    if blocker then
        notify_delete_error(blocker)
        return false
    end

    local replacement = replacement_buffer(current)

    if replacement then
        vim.api.nvim_win_set_buf(0, replacement)
    else
        vim.cmd("enew")
    end

    local ok, err = delete_buffer(current, force)

    if not ok then
        notify_delete_error(err)
    end

    return ok
end

function M.delete_others(force)
    local current = vim.api.nvim_get_current_buf()

    local ok, err = delete_others_except(current, force)

    if not ok then
        notify_delete_error(err)
    end

    return ok
end

return M
