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
        display = entry.disabled and function()
            return entry.label, {{{0, #entry.label}, 'Comment'}}
        end or entry.label,
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

                    if selected and selected.value and selected.value.disabled then return end
                    M.close(prompt_bufnr, telescope)

                    if selected and selected.value and selected.value.action then
                        selected.value.action(selected.value)
                    end
                end

                local has_disabled = false
                for _, entry in ipairs(entries) do has_disabled = has_disabled or entry.disabled end
                if has_disabled then
                    -- Skip disabled rows for both keyboard movement and mouse selection.
                    local current_picker = telescope.action_state.get_current_picker(prompt_bufnr)
                    local original_selection = current_picker.set_selection
                    current_picker.set_selection = function(self, row)
                        if self.manager then
                            row = self.scroller(self.max_results, self.manager:num_results(), row)
                            local direction = row < (self:get_selection_row() or row) and -1 or 1
                            local candidate = row
                            local entry = self.manager:get_entry(self:get_index(candidate))
                            while entry and entry.value and entry.value.disabled do
                                candidate = candidate + direction
                                entry = self.manager:get_entry(self:get_index(candidate))
                            end
                            if not entry then return end
                            row = candidate
                        end
                        return original_selection(self, row)
                    end
                    local function mouse_select(activate)
                        local mouse = vim.fn.getmousepos()
                        if mouse.winid ~= current_picker.results_win then return end
                        local row = mouse.line - 1
                        local entry = current_picker.manager and current_picker.manager:get_entry(current_picker:get_index(row))
                        if not entry or (entry.value and entry.value.disabled) then return end
                        current_picker:set_selection(row)
                        if activate then select_entry() end
                    end
                    for _, mode in ipairs({'n', 'i'}) do
                        map(mode, '<LeftMouse>', function() mouse_select(false) end)
                        map(mode, '<2-LeftMouse>', function() mouse_select(true) end)
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
