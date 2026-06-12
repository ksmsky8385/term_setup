local M = {}

local session_entries = require("config.sessions.entries")
local metadata_store = require("config.sessions.metadata")
local session_note = require("config.sessions.note")
local session_buffers = require("config.sessions.buffers")
local session_paths = require("config.sessions.paths")
local session_restore = require("config.sessions.restore")
local session_slots = require("config.sessions.slots")
local session_store = require("config.sessions.store")

local session_path = session_paths.session_path
local known_slot_ids = session_slots.known_ids
local known_slot_id = session_slots.known
local prepare_session_load = session_buffers.prepare_load
local preview_lines = session_entries.preview_lines
local read_metadata = metadata_store.read
local slot_entry = session_entries.slot_entry
local active_session_slot = nil

function M.configured_slot_ids()
    return session_slots.configured_ids()
end

local function load_telescope()
    local ok, telescope = pcall(function()
        return {
            actions = require("telescope.actions"),
            action_state = require("telescope.actions.state"),
            action_set = require("telescope.actions.set"),
            conf = require("telescope.config").values,
            finders = require("telescope.finders"),
            pickers = require("telescope.pickers"),
            previewers = require("telescope.previewers"),
        }
    end)

    if not ok then
        vim.notify("telescope.nvim is not available", vim.log.levels.ERROR)
        return nil
    end

    return telescope
end

function M.save(slot, force, opts)
    return session_store.save(slot, force, opts)
end

function M.move(from_slot, to_slot, opts)
    local ok, next_slot, state = session_store.move(from_slot, to_slot, opts)

    if ok and state then
        if active_session_slot == state.from_slot then
            active_session_slot = next_slot
        elseif state.to_exists and active_session_slot == next_slot then
            active_session_slot = state.from_slot
        end
    end

    return ok, next_slot
end

local function load_session(slot, path)
    local metadata = read_metadata(slot)
    local cwd = metadata.cwd
    local workspace = vim.fn.getcwd()

    if type(cwd) == "string" and cwd ~= "" then
        if vim.fn.isdirectory(cwd) == 1 then
            pcall(vim.cmd, "cd " .. vim.fn.fnameescape(cwd))
            workspace = vim.fn.getcwd()
        else
            vim.notify(
                "Session workspace is missing: " .. cwd .. ". Using current workspace: " .. workspace,
                vim.log.levels.WARN
            )
        end
    end

    vim.g.current_workspace_root = workspace

    local ok, err = pcall(function()
        vim.cmd("source " .. vim.fn.fnameescape(path))
    end)

    if not ok then
        vim.notify("Failed to load session " .. slot .. ": " .. err, vim.log.levels.ERROR)
        return
    end

    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(workspace))
    vim.g.current_workspace_root = vim.fn.getcwd()

    vim.schedule(function()
        session_restore.after_load(metadata)

        if type(metadata.winrestcmd) == "string" and metadata.winrestcmd ~= "" then
            pcall(vim.cmd, metadata.winrestcmd)
        end
    end)

    vim.notify("Loaded session " .. slot)
    active_session_slot = slot
end

function M.load(slot)
    slot = known_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    local path = session_path(slot)

    if not session_store.exists(slot) then
        vim.notify("Session " .. slot .. " is empty.", vim.log.levels.WARN)
        return
    end

    prepare_session_load(function()
        load_session(slot, path)
    end)
end

function M.note(slot, opts)
    session_note.open_editor(slot, opts)
end

function M.name(slot, opts)
    session_note.edit_field(slot, "name", "name", opts)
end

function M.delete(slot, force, opts)
    opts = opts or {}
    local on_deleted = opts.on_deleted

    opts.on_deleted = function(deleted_slot)
        if active_session_slot == deleted_slot then
            active_session_slot = nil
        end

        if on_deleted then
            on_deleted(deleted_slot)
        end
    end

    return session_store.delete(slot, force, opts)
end

local function scroll_window(win, amount)
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end

    local current_win = vim.api.nvim_get_current_win()

    vim.api.nvim_set_current_win(win)

    if amount > 0 then
        vim.cmd("normal! " .. amount .. "\25")
    elseif amount < 0 then
        vim.cmd("normal! " .. math.abs(amount) .. "\5")
    end

    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
end

function M.pick(opts)
    opts = opts or {}
    local telescope = load_telescope()

    if not telescope then
        return
    end

    local entries = {}
    local default_selection_index = nil
    local default_slot = opts.default_slot or active_session_slot

    for _, slot in ipairs(known_slot_ids()) do
        table.insert(entries, slot_entry(slot))

        if slot == default_slot then
            default_selection_index = #entries
        end
    end

    telescope.pickers
        .new({}, {
            initial_mode = "normal",
            default_selection_index = default_selection_index,
            prompt_title = "Sessions",
            results_title = "Enter load | w write | m move/swap | n name | e note | d delete",
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.label,
                        ordinal = entry.ordinal,
                    }
                end,
            }),
            previewer = telescope.previewers.new_buffer_previewer({
                define_preview = function(self, entry)
                    vim.api.nvim_buf_set_lines(
                        self.state.bufnr,
                        0,
                        -1,
                        false,
                        preview_lines(entry.value)
                    )
                end,
            }),
            sorter = telescope.conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                local ok_picker, attached_picker = pcall(
                    telescope.action_state.get_current_picker,
                    prompt_bufnr
                )

                if not ok_picker then
                    attached_picker = nil
                end

                local floating_preview = {
                    buf = nil,
                    win = nil,
                }

                local entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.label,
                        ordinal = entry.ordinal,
                    }
                end

                local picker_for_prompt = function()
                    local picker = attached_picker

                    if not picker then
                        local ok, current_picker = pcall(
                            telescope.action_state.get_current_picker,
                            prompt_bufnr
                        )

                        if ok then
                            picker = current_picker
                        end
                    end

                    return picker
                end

                local select_slot = function(slot)
                    if not slot then
                        return false
                    end

                    local picker = picker_for_prompt()

                    if not picker or not picker.manager then
                        return false
                    end

                    local count = picker.manager:num_results()

                    for index = 1, count do
                        local entry = picker.manager:get_entry(index)

                        if entry and entry.value and entry.value.slot == slot then
                            picker:set_selection(picker:get_row(index))
                            return true
                        end
                    end

                    return false
                end

                local select_row = function(row)
                    local picker = picker_for_prompt()

                    if not picker or not picker.manager or row == nil then
                        return false
                    end

                    local count = picker.manager:num_results()

                    if count == 0 then
                        return false
                    end

                    local index = math.min(picker:get_index(row), count)

                    picker:set_selection(picker:get_row(index))
                    return true
                end

                local focus_prompt = function()
                    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
                        return
                    end

                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                        if vim.api.nvim_win_get_buf(win) == prompt_bufnr then
                            vim.api.nvim_set_current_win(win)
                            return
                        end
                    end
                end

                local restore_selection

                restore_selection = function(slot, row, attempt)
                    attempt = attempt or 0
                    focus_prompt()

                    if select_slot(slot) or select_row(row) then
                        return
                    end

                    if attempt < 6 then
                        vim.defer_fn(function()
                            restore_selection(slot, row, attempt + 1)
                        end, 20)
                    end
                end

                local refresh_picker = function(slot_to_select, row_to_select)
                    local refreshed = {}
                    local default_selection_index = nil

                    for _, slot in ipairs(known_slot_ids()) do
                        table.insert(refreshed, slot_entry(slot))

                        if slot == slot_to_select then
                            default_selection_index = #refreshed
                        end
                    end

                    local picker = picker_for_prompt()

                    if not picker then
                        return
                    end

                    picker.default_selection_index = default_selection_index
                    picker:refresh(telescope.finders.new_table({
                        results = refreshed,
                        entry_maker = entry_maker,
                    }), {
                        reset_prompt = false,
                    })

                    vim.schedule(function()
                        restore_selection(slot_to_select, row_to_select)
                    end)
                end

                local notify_after_picker_update = function(message)
                    vim.defer_fn(function()
                        vim.notify(message)
                    end, 50)
                end

                local selected_slot = function()
                    local selected = telescope.action_state.get_selected_entry()

                    if not selected or not selected.value then
                        return nil
                    end

                    return selected.value.slot
                end

                local selected_row = function()
                    local picker = picker_for_prompt()

                    if picker then
                        return picker:get_selection_row()
                    end

                    return nil
                end

                local function close_floating_preview()
                    if
                        floating_preview.win
                        and vim.api.nvim_win_is_valid(floating_preview.win)
                    then
                        vim.api.nvim_win_close(floating_preview.win, true)
                    end

                    if
                        floating_preview.buf
                        and vim.api.nvim_buf_is_valid(floating_preview.buf)
                    then
                        vim.api.nvim_buf_delete(floating_preview.buf, {
                            force = true,
                        })
                    end

                    floating_preview.buf = nil
                    floating_preview.win = nil
                end

                local function automatic_preview_visible()
                    local picker = telescope.action_state.get_current_picker(prompt_bufnr)

                    return picker
                        and picker.preview_win
                        and vim.api.nvim_win_is_valid(picker.preview_win)
                end

                local function toggle_floating_preview()
                    if automatic_preview_visible() then
                        return
                    end

                    if
                        floating_preview.win
                        and vim.api.nvim_win_is_valid(floating_preview.win)
                    then
                        close_floating_preview()
                        return
                    end

                    local selected = telescope.action_state.get_selected_entry()

                    if not selected or not selected.value then
                        return
                    end

                    local width = math.min(
                        math.max(52, math.floor(vim.o.columns * 0.72)),
                        vim.o.columns - 4
                    )
                    local height = math.min(
                        math.max(12, math.floor(vim.o.lines * 0.62)),
                        vim.o.lines - 4
                    )
                    local buf = vim.api.nvim_create_buf(false, true)
                    local win = vim.api.nvim_open_win(buf, false, {
                        relative = "editor",
                        width = width,
                        height = height,
                        row = math.floor((vim.o.lines - height) / 2),
                        col = math.floor((vim.o.columns - width) / 2),
                        border = "rounded",
                        title = " Session preview ",
                        title_pos = "center",
                    })

                    vim.bo[buf].bufhidden = "wipe"
                    vim.bo[buf].buftype = "nofile"
                    vim.bo[buf].swapfile = false
                    vim.wo[win].wrap = false
                    vim.wo[win].cursorline = true
                    vim.api.nvim_buf_set_lines(
                        buf,
                        0,
                        -1,
                        false,
                        preview_lines(selected.value)
                    )
                    vim.bo[buf].modifiable = false

                    vim.keymap.set("n", "<C-u>", function()
                        scroll_window(win, 8)
                    end, {
                        buffer = buf,
                        silent = true,
                    })

                    vim.keymap.set("n", "<C-d>", function()
                        scroll_window(win, -8)
                    end, {
                        buffer = buf,
                        silent = true,
                    })

                    vim.keymap.set("n", "<PageUp>", function()
                        scroll_window(win, 12)
                    end, {
                        buffer = buf,
                        silent = true,
                    })

                    vim.keymap.set("n", "<PageDown>", function()
                        scroll_window(win, -12)
                    end, {
                        buffer = buf,
                        silent = true,
                    })

                    floating_preview.buf = buf
                    floating_preview.win = win
                end

                local function close_picker()
                    close_floating_preview()
                    telescope.actions.close(prompt_bufnr)
                end

                telescope.actions.select_default:replace(function()
                    local slot = selected_slot()

                    close_picker()

                    if slot ~= nil then
                        M.load(slot)
                    end
                end)

                local save_selected = function()
                    local slot = selected_slot()

                    if slot ~= nil then
                        local reopen = function()
                            vim.schedule(function()
                                M.pick({
                                    default_slot = slot,
                                })
                            end)
                        end

                        M.save(slot, false, {
                            notify = false,
                            before_write = function()
                                close_picker()
                            end,
                            on_update = function()
                                reopen()
                                notify_after_picker_update("Saved session " .. slot)
                            end,
                            on_cancel = function()
                                reopen()
                            end,
                        })
                    end
                end

                local move_selected = function()
                    local slot = selected_slot()
                    local row = selected_row()

                    if slot == nil then
                        return
                    end

                    vim.ui.input({
                        prompt = "Move session " .. slot .. " to configured slot: ",
                    }, function(target)
                        if target == nil or target == "" then
                            restore_selection(slot, row)
                            return
                        end

                        local ok = M.move(slot, target, {
                            on_update = function(next_slot)
                                refresh_picker(next_slot)
                            end,
                        })

                        if not ok then
                            restore_selection(slot, row)
                        end
                    end)
                end

                local note_selected = function()
                    local slot = selected_slot()
                    local row = selected_row()

                    if slot ~= nil then
                        M.note(slot, {
                            notify = false,
                            on_update = function()
                                refresh_picker(slot, row)
                                notify_after_picker_update("Updated session " .. slot .. " note")
                            end,
                            on_close = function()
                                vim.schedule(function()
                                    local prompt_win = nil

                                    if vim.api.nvim_buf_is_valid(prompt_bufnr) then
                                        for _, win in ipairs(vim.api.nvim_list_wins()) do
                                            if vim.api.nvim_win_get_buf(win) == prompt_bufnr then
                                                prompt_win = win
                                                break
                                            end
                                        end
                                    end

                                    if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
                                        vim.api.nvim_set_current_win(prompt_win)
                                        restore_selection(slot, row)
                                    else
                                        M.pick({
                                            default_slot = slot,
                                        })
                                    end
                                end)
                            end,
                        })
                    end
                end

                local name_selected = function()
                    local slot = selected_slot()
                    local row = selected_row()

                    if slot ~= nil then
                        M.name(slot, {
                            on_update = function()
                                refresh_picker(slot, row)
                            end,
                            on_cancel = function()
                                restore_selection(slot, row)
                            end,
                        })
                    end
                end

                local delete_selected = function()
                    local slot = selected_slot()
                    local row = selected_row()

                    if slot ~= nil then
                        M.delete(slot, false, {
                            on_update = function()
                                refresh_picker(slot, row)
                            end,
                            on_cancel = function()
                                restore_selection(slot, row)
                            end,
                        })
                    end
                end

                map("n", "w", save_selected)
                map("n", "m", move_selected)
                map("n", "n", name_selected)
                map("n", "e", note_selected)
                map("n", "d", delete_selected)
                map("n", "<Tab>", toggle_floating_preview)
                map("n", "<C-u>", function()
                    telescope.action_set.scroll_previewer(prompt_bufnr, -1)
                end)
                map("n", "<C-d>", function()
                    telescope.action_set.scroll_previewer(prompt_bufnr, 1)
                end)
                map("n", "<PageUp>", function()
                    telescope.action_set.scroll_previewer(prompt_bufnr, -1)
                end)
                map("n", "<PageDown>", function()
                    telescope.action_set.scroll_previewer(prompt_bufnr, 1)
                end)

                local close_preview_or_picker = function()
                    if
                        floating_preview.win
                        and vim.api.nvim_win_is_valid(floating_preview.win)
                    then
                        close_floating_preview()
                    else
                        close_picker()
                    end
                end

                map("n", "<Esc>", close_preview_or_picker)

                return true
            end,
        })
        :find()
end

return M
