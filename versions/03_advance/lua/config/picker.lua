local M = {}

function M.load(opts)
    opts = opts or {}

    local ok, telescope = pcall(function()
        return {
            actions = require("telescope.actions"),
            action_set = opts.action_set and require("telescope.actions.set") or nil,
            action_state = require("telescope.actions.state"),
            conf = require("telescope.config").values,
            finders = require("telescope.finders"),
            make_entry = opts.make_entry and require("telescope.make_entry") or nil,
            pickers = require("telescope.pickers"),
            previewers = opts.previewers and require("telescope.previewers") or nil,
            sorters = opts.sorters and require("telescope.sorters") or nil,
        }
    end)

    if not ok then
        if opts.notify ~= false then
            vim.notify("telescope.nvim is not available", vim.log.levels.ERROR)
        end
        return nil
    end

    return telescope
end

function M.entry_maker(entry)
    return {
        value = entry,
        display = entry.label,
        ordinal = entry.ordinal or entry.label,
    }
end

function M.selected_entry(prompt_bufnr, telescope)
    telescope = telescope or M.load({
        notify = false,
    })

    if not telescope then
        return nil
    end

    return telescope.action_state.get_selected_entry(prompt_bufnr)
end

function M.close(prompt_bufnr, telescope)
    telescope = telescope or M.load({
        notify = false,
    })

    if not telescope then
        return
    end

    telescope.actions.close(prompt_bufnr)
end

function M.action_picker(title, entries, opts)
    opts = opts or {}

    local telescope = M.load()

    if not telescope then
        return
    end

    telescope.pickers
        .new(opts.picker_opts or {}, {
            prompt_title = title,
            initial_mode = opts.initial_mode,
            default_selection_index = opts.default_selection_index,
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = opts.entry_maker or M.entry_maker,
            }),
            sorter = opts.sorter or telescope.conf.generic_sorter({}),
            previewer = opts.previewer or false,
            attach_mappings = function(prompt_bufnr, map)
                local select_entry = function()
                    local selected = M.selected_entry(prompt_bufnr, telescope)

                    M.close(prompt_bufnr, telescope)

                    if selected and selected.value and selected.value.action then
                        selected.value.action(selected.value)
                    end
                end

                telescope.actions.select_default:replace(select_entry)

                if opts.mappings then
                    opts.mappings(prompt_bufnr, map, telescope)
                end

                return true
            end,
        })
        :find()
end

return M
