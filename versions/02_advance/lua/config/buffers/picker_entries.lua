local policy = require("config.buffers.policy")
local state = require("config.buffers.state")

local M = {}

local function visible_tab_labels_by_buffer()
    local ok_picker, window_picker = pcall(require, "config.window_picker")
    local labels = {}
    local max_width = 0
    local floating_labels = {}
    local show_tab_label = vim.fn.tabpagenr("$") > 1
    if not ok_picker then
        return labels, max_width
    end

    for tabnr, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        local tab_labels = {}
        local previous_tabpage = vim.api.nvim_get_current_tabpage()
        local ok_floating, floating = pcall(require, "config.floating")

        vim.api.nvim_set_current_tabpage(tabpage)

        for _, win in ipairs(window_picker.selectable_windows(policy.window_picker_exclude)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local window_label = window_picker.label_for_window(win, policy.window_picker_exclude)

            if state.valid_listed(buf) and window_label ~= "" then
                if ok_floating and floating.is_slot_window(win) then
                    labels[buf] = labels[buf] or {}
                    floating_labels[buf] = floating_labels[buf] or {}

                    if not floating_labels[buf][window_label] then
                        table.insert(labels[buf], "[" .. window_label .. "]")
                        floating_labels[buf][window_label] = true
                    end
                else
                    tab_labels[buf] = tab_labels[buf] or {}
                    table.insert(tab_labels[buf], window_label)
                end
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

    local ok_floating, floating = pcall(require, "config.floating")

    if ok_floating and type(floating.assigned_slots_by_buffer) == "function" then
        for buf, slots in pairs(floating.assigned_slots_by_buffer()) do
            if state.valid_listed(buf) then
                labels[buf] = labels[buf] or {}
                floating_labels[buf] = floating_labels[buf] or {}

                for _, slot in ipairs(slots) do
                    if not floating_labels[buf][slot.label] then
                        table.insert(labels[buf], "[" .. slot.label .. "]")
                        floating_labels[buf][slot.label] = true
                    end
                end
            end
        end
    end

    for buf, buf_labels in pairs(labels) do
        labels[buf] = table.concat(buf_labels, " ")
        max_width = math.max(max_width, #labels[buf])
    end

    return labels, max_width
end

function M.entry_maker(opts, telescope)
    local base_maker = telescope.make_entry.gen_from_buffer(opts)
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
                local rendered_label = label:sub(1, 1) == "[" and label or "[" .. label .. "]"

                prefix = string.format("%-" .. (label_width + 2) .. "s ", rendered_label)
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

function M.sorter(opts, telescope)
    local generic = telescope.conf.generic_sorter(opts)

    return telescope.sorters.Sorter:new({
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

function M.results(initial_buf)
    local bufnrs = state.sorted_numbers()

    if not next(bufnrs) then
        return nil
    end

    local buffers = {}
    local default_selection_index = nil

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

    return buffers, default_selection_index, #tostring(math.max(unpack(bufnrs)))
end

return M
