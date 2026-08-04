local telescope_picker = require("config.picker")
local entries = require("config.buffers.picker_entries")
local picker_actions = require("config.buffers.picker_actions")

local M = {}

local function buffer_picker(initial_buf, telescope, operations)
    local buffers, default_selection_index, bufnr_width = entries.results(initial_buf)

    if not buffers then
        vim.notify("No buffers found", vim.log.levels.INFO)
        return
    end

    local opts = {
        bufnr_width = bufnr_width,
        initial_mode = "normal",
        sort_mru = true,
        ignore_current_buffer = false,
    }

    telescope.pickers.new(opts, {
        prompt_title = "Buffers",
        results_title = "Enter open | w window | m move | s/v split | d/D delete | o/O keep only",
        default_selection_index = default_selection_index,
        finder = telescope.finders.new_table({
            results = buffers,
            entry_maker = entries.entry_maker(opts, telescope),
        }),
        previewer = telescope.conf.grep_previewer(opts),
        sorter = entries.sorter(opts, telescope),
        attach_mappings = function(prompt_bufnr, map)
            map("i", "<CR>", function()
                picker_actions.open_selected(prompt_bufnr, operations)
            end)

            map("n", "<CR>", function()
                picker_actions.open_selected(prompt_bufnr, operations)
            end)

            map("n", "d", function()
                picker_actions.delete_selected(prompt_bufnr, false, operations)
            end)

            map("n", "D", function()
                picker_actions.delete_selected(prompt_bufnr, true, operations)
            end)

            map("n", "o", function()
                picker_actions.keep_selected_only(prompt_bufnr, false, operations)
            end)

            map("n", "O", function()
                picker_actions.keep_selected_only(prompt_bufnr, true, operations)
            end)

            map("n", "w", function()
                picker_actions.open_in_window_selected(prompt_bufnr, operations)
            end)

            map("n", "m", function()
                picker_actions.move_selected(prompt_bufnr, operations)
            end)

            map("n", "s", function()
                picker_actions.split_selected(prompt_bufnr, "rightbelow split", operations)
            end)

            map("n", "v", function()
                picker_actions.split_selected(prompt_bufnr, "rightbelow vsplit", operations)
            end)

            return true
        end,
    }):find()
end

function M.pick(initial_buf, operations)
    local telescope = telescope_picker.load({
        make_entry = true,
        notify = false,
        sorters = true,
    })

    if telescope then
        buffer_picker(initial_buf, telescope, operations)
        return
    end

    vim.cmd("buffers")
end

return M
