local M = {}

local session_dir = vim.fn.stdpath("state") .. "/sessions"
local active_session_slot = nil
local session_slot_ids = {
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
}
local session_options = {
    "buffers",
    "folds",
    "help",
    "tabpages",
    "terminal",
    "winsize",
}

local function configured_slot_lookup()
    local lookup = {}

    for _, slot in ipairs(session_slot_ids) do
        lookup[slot] = true
    end

    return lookup
end

local function normalize_slot_id(slot)
    if slot == nil then
        return nil
    end

    slot = tostring(slot)

    if slot == "" or not slot:match("^[%w]+$") then
        return nil
    end

    return slot
end

local function configured_slot_id(slot)
    slot = normalize_slot_id(slot)

    if not slot or not configured_slot_lookup()[slot] then
        return nil
    end

    return slot
end

local function configured_slot_message()
    return "Session slot must be one of: " .. table.concat(session_slot_ids, ", ")
end

local function session_path(slot)
    return session_dir .. "/slot-" .. slot .. ".vim"
end

local function metadata_path(slot)
    return session_dir .. "/slot-" .. slot .. ".json"
end

local function slot_id_from_filename(filename)
    return filename:match("^slot%-([%w]+)%.vim$")
        or filename:match("^slot%-([%w]+)%.json$")
end

local function disk_slot_ids()
    local ids = {}
    local seen = {}

    if vim.fn.isdirectory(session_dir) == 0 then
        return ids
    end

    for _, filename in ipairs(vim.fn.readdir(session_dir)) do
        local slot = slot_id_from_filename(filename)

        if slot and not seen[slot] then
            table.insert(ids, slot)
            seen[slot] = true
        end
    end

    table.sort(ids)

    return ids
end

local function known_slot_ids()
    local ids = {}
    local seen = {}

    for _, slot in ipairs(session_slot_ids) do
        table.insert(ids, slot)
        seen[slot] = true
    end

    for _, slot in ipairs(disk_slot_ids()) do
        if not seen[slot] then
            table.insert(ids, slot)
            seen[slot] = true
        end
    end

    return ids
end

local function known_slot_id(slot)
    slot = normalize_slot_id(slot)

    if not slot then
        return nil
    end

    for _, known in ipairs(known_slot_ids()) do
        if known == slot then
            return slot
        end
    end

    return nil
end

function M.configured_slot_ids()
    return vim.deepcopy(session_slot_ids)
end

local function read_metadata(slot)
    local path = metadata_path(slot)

    if vim.fn.filereadable(path) == 0 then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))

    if not ok or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

local function write_metadata(slot, metadata)
    vim.fn.mkdir(session_dir, "p")
    vim.fn.writefile({
        vim.json.encode(metadata),
    }, metadata_path(slot))
end

local function current_files()
    local files = {}
    local seen = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)

        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.bo[buf].buftype ~= "terminal"
            and name ~= ""
            and not seen[name]
        then
            table.insert(files, name)
            seen[name] = true
        end
    end

    table.sort(files)

    return files
end

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function buffer_name(buf)
    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":~:.")
end

local function session_load_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_valid(buf)
            and (
                vim.bo[buf].buflisted
                or vim.bo[buf].buftype == "terminal"
            )
        then
            table.insert(buffers, buf)
        end
    end

    return buffers
end

local function session_load_blockers(buffers)
    local blockers = {}

    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            if vim.bo[buf].modified then
                table.insert(blockers, "Unsaved changes: " .. buffer_name(buf))
            elseif vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) then
                table.insert(blockers, "Running terminal: " .. buffer_name(buf))
            end
        end
    end

    return blockers
end

local function clear_session_load_buffers(buffers, force)
    vim.cmd("enew")

    local keep = vim.api.nvim_get_current_buf()

    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) and buf ~= keep then
            if force and vim.bo[buf].buftype == "terminal" then
                local job_id = vim.b[buf].terminal_job_id

                if terminal_job_running(buf) then
                    pcall(vim.fn.jobstop, job_id)
                end
            end

            local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
                force = force,
            })

            if not ok then
                return false, "Failed to delete " .. buffer_name(buf) .. ": " .. err
            end
        end
    end

    return true
end

local function prepare_session_load(callback)
    local buffers = session_load_buffers()
    local blockers = session_load_blockers(buffers)

    if #blockers == 0 then
        local ok, err = clear_session_load_buffers(buffers, false)

        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        callback()
        return
    end

    vim.ui.input({
        prompt = table.concat(blockers, " | ")
            .. " | Type Q to force session switch, anything else cancels: ",
    }, function(answer)
        if answer ~= "Q" then
            vim.notify("Session switch cancelled.", vim.log.levels.INFO)
            return
        end

        local ok, err = clear_session_load_buffers(buffers, true)

        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        callback()
    end)
end

local function tabpage_windows(tab)
    return vim.tbl_filter(function(win)
        return vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == ""
    end, vim.api.nvim_tabpage_list_wins(tab))
end

local function current_terminal_windows()
    local terminals = {}

    for tab_index, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for win_index, win in ipairs(tabpage_windows(tab)) do
            local buf = vim.api.nvim_win_get_buf(win)

            if vim.bo[buf].buftype == "terminal" then
                local cwd = vim.api.nvim_win_call(win, function()
                    return vim.fn.getcwd()
                end)

                table.insert(terminals, {
                    tab = tab_index,
                    win = win_index,
                    shell = vim.o.shell,
                    cwd = cwd,
                })
            end
        end
    end

    return terminals
end

local function current_tree_state()
    local ok, api = pcall(require, "nvim-tree.api")

    return {
        visible = ok and api.tree.is_visible() == true,
    }
end

local function restore_terminals(terminals)
    if type(terminals) ~= "table" or #terminals == 0 then
        return
    end

    local ok, terminal = pcall(require, "config.terminal")

    if not ok then
        return
    end

    for _, item in ipairs(terminals) do
        local tab = vim.api.nvim_list_tabpages()[item.tab]

        if tab and vim.api.nvim_tabpage_is_valid(tab) then
            local wins = tabpage_windows(tab)
            local win = wins[item.win]

            if win and vim.api.nvim_win_is_valid(win) then
                local buf = vim.api.nvim_win_get_buf(win)

                if terminal.valid_terminal(buf) then
                    goto continue
                end

                vim.api.nvim_set_current_tabpage(tab)
                vim.api.nvim_set_current_win(win)

                if item.cwd and vim.fn.isdirectory(item.cwd) == 1 then
                    pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(item.cwd))
                end

                pcall(terminal.create_buffer_terminal)
            end
        end

        ::continue::
    end
end

local function restore_tree(tree)
    if type(tree) ~= "table" or not tree.visible then
        return
    end

    local ok, api = pcall(require, "nvim-tree.api")

    if not ok then
        return
    end

    local current_win = vim.api.nvim_get_current_win()

    pcall(api.tree.open, {
        focus = false,
    })

    if vim.api.nvim_win_is_valid(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function clear_missing_file_buffers()
    local missing = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)

        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.bo[buf].buftype == ""
            and name ~= ""
            and vim.fn.filereadable(name) == 0
        then
            table.insert(missing, vim.fn.fnamemodify(name, ":~:."))

            for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
                    if
                        vim.api.nvim_win_is_valid(win)
                        and vim.api.nvim_win_get_buf(win) == buf
                    then
                        local fallback = vim.api.nvim_create_buf(false, true)

                        vim.bo[fallback].buflisted = false
                        vim.api.nvim_win_set_buf(win, fallback)
                    end
                end
            end

            pcall(vim.api.nvim_buf_delete, buf, {
                force = true,
            })
        end
    end

    if #missing > 0 then
        vim.notify("Missing session files: " .. table.concat(missing, ", "), vim.log.levels.WARN)
    end
end

local function file_mtime(path)
    local stat = vim.loop.fs_stat(path)

    if not stat or not stat.mtime or not stat.mtime.sec then
        return nil
    end

    return stat.mtime.sec
end

local function session_exists(slot)
    return vim.fn.filereadable(session_path(slot)) == 1
end

local function slot_files(slot)
    return {
        session_path(slot),
        metadata_path(slot),
    }
end

local function move_file(from, to)
    if vim.fn.filereadable(from) == 0 then
        return true
    end

    local ok = vim.fn.rename(from, to) == 0

    if not ok then
        vim.notify("Failed to move " .. from .. " to " .. to, vim.log.levels.ERROR)
    end

    return ok
end

local function update_metadata_slot(slot)
    local metadata = read_metadata(slot)

    if vim.tbl_isempty(metadata) then
        return
    end

    metadata.slot = slot
    write_metadata(slot, metadata)
end

local function first_files(files, count)
    local selected = {}

    for index, file in ipairs(files or {}) do
        if index > count then
            break
        end

        table.insert(selected, vim.fn.fnamemodify(file, ":~:."))
    end

    return selected
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

local function with_session_options(callback)
    local previous = vim.o.sessionoptions

    vim.o.sessionoptions = table.concat(session_options, ",")

    local ok, err = pcall(callback)

    vim.o.sessionoptions = previous

    if not ok then
        error(err)
    end
end

function M.save(slot, force, opts)
    opts = opts or {}
    slot = configured_slot_id(slot)

    if slot == nil then
        vim.notify(configured_slot_message(), vim.log.levels.ERROR)
        if opts.on_cancel then
            opts.on_cancel()
        end
        return
    end

    if session_exists(slot) and not force then
        vim.ui.input({
            prompt = "Overwrite session " .. slot .. "? Type y to confirm: ",
        }, function(answer)
            if answer == "y" or answer == "Y" then
                M.save(slot, true, opts)
            elseif opts.on_cancel then
                opts.on_cancel()
            end
        end)

        return
    end

    if opts.before_write then
        opts.before_write()
    end

    vim.fn.mkdir(session_dir, "p")

    local path = session_path(slot)
    local ok, err = pcall(function()
        with_session_options(function()
            vim.cmd("mksession! " .. vim.fn.fnameescape(path))
        end)
    end)

    if not ok then
        vim.notify("Failed to save session " .. slot .. ": " .. err, vim.log.levels.ERROR)
        if opts.on_cancel then
            opts.on_cancel()
        end
        return
    end

    local metadata = read_metadata(slot)

    metadata.slot = slot
    metadata.cwd = vim.fn.getcwd()
    metadata.files = current_files()
    metadata.terminals = current_terminal_windows()
    metadata.tree = current_tree_state()
    metadata.winrestcmd = vim.fn.winrestcmd()
    metadata.saved_at = os.date("%Y-%m-%d %H:%M:%S")

    write_metadata(slot, metadata)

    if opts.notify ~= false then
        vim.notify("Saved session " .. slot)
    end

    if opts.on_update then
        opts.on_update()
    end
end

function M.move(from_slot, to_slot, opts)
    opts = opts or {}
    from_slot = known_slot_id(from_slot)
    to_slot = configured_slot_id(to_slot)

    if from_slot == nil then
        vim.notify("Source session slot is not known.", vim.log.levels.ERROR)
        return false
    end

    if to_slot == nil then
        vim.notify(configured_slot_message(), vim.log.levels.ERROR)
        return false
    end

    if from_slot == to_slot then
        vim.notify("Session is already in slot " .. from_slot, vim.log.levels.INFO)
        return false
    end

    if not session_exists(from_slot) then
        vim.notify("Session " .. from_slot .. " is empty.", vim.log.levels.WARN)
        return false
    end

    vim.fn.mkdir(session_dir, "p")

    local tmp_base = session_dir
        .. "/slot-swap-"
        .. from_slot
        .. "-"
        .. to_slot
        .. "-"
        .. vim.fn.localtime()
    local from_files = slot_files(from_slot)
    local to_files = slot_files(to_slot)
    local tmp_files = {
        tmp_base .. ".vim",
        tmp_base .. ".json",
    }
    local to_exists = session_exists(to_slot)

    for index, path in ipairs(from_files) do
        if not move_file(path, tmp_files[index]) then
            return false
        end
    end

    if to_exists then
        for index, path in ipairs(to_files) do
            if not move_file(path, from_files[index]) then
                return false
            end
        end
    end

    for index, path in ipairs(tmp_files) do
        if not move_file(path, to_files[index]) then
            return false
        end
    end

    update_metadata_slot(from_slot)
    update_metadata_slot(to_slot)

    if to_exists then
        vim.notify("Swapped sessions " .. from_slot .. " and " .. to_slot)
    else
        vim.notify("Moved session " .. from_slot .. " to " .. to_slot)
    end

    if active_session_slot == from_slot then
        active_session_slot = to_slot
    elseif to_exists and active_session_slot == to_slot then
        active_session_slot = from_slot
    end

    if opts.on_update then
        opts.on_update(to_slot)
    end

    return true, to_slot
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
        clear_missing_file_buffers()
        restore_terminals(metadata.terminals)
        restore_tree(metadata.tree)

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

    if vim.fn.filereadable(path) == 0 then
        vim.notify("Session " .. slot .. " is empty.", vim.log.levels.WARN)
        return
    end

    prepare_session_load(function()
        load_session(slot, path)
    end)
end

local function edit_metadata_field(slot, field, label, opts)
    opts = opts or {}
    slot = known_slot_id(slot) or configured_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    local metadata = read_metadata(slot)
    local previous = metadata[field] or ""

    vim.ui.input({
        prompt = "Session " .. slot .. " " .. label .. ": ",
        default = previous,
    }, function(value)
        if value == nil then
            if opts.on_cancel then
                opts.on_cancel()
            end
            return
        end

        if value == previous then
            if opts.on_cancel then
                opts.on_cancel()
            end
            return
        end

        vim.ui.input({
            prompt = "Update session " .. slot .. " " .. label .. "? Type y to confirm: ",
        }, function(answer)
            if answer ~= "y" and answer ~= "Y" then
                if opts.on_cancel then
                    opts.on_cancel()
                end
                return
            end

            metadata = read_metadata(slot)
            metadata.slot = slot
            metadata[field] = value

            write_metadata(slot, metadata)
            vim.notify("Updated session " .. slot .. " " .. label)

            if opts.on_update then
                opts.on_update()
            end
        end)
    end)
end

local function split_lines(text)
    if text == "" then
        return {}
    end

    local lines = vim.split(text, "\n", {
        plain = true,
    })

    return lines
end

local function open_note_editor(slot, opts)
    opts = opts or {}
    slot = known_slot_id(slot) or configured_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    local metadata = read_metadata(slot)
    local previous = metadata.note or ""
    local width = math.min(math.max(60, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
    local height = math.min(math.max(12, math.floor(vim.o.lines * 0.55)), vim.o.lines - 4)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
        title = " Session " .. slot .. " note ",
        title_pos = "center",
    })

    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].swapfile = false
    vim.wo[win].wrap = true

    local ok_cmp, cmp = pcall(require, "cmp")

    if ok_cmp then
        cmp.setup.buffer({
            enabled = false,
        })
    end

    local initial_lines = split_lines(previous)

    if #initial_lines == 0 then
        initial_lines = { "" }
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)

    local function current_note()
        return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end

    local function stop_insert_mode()
        if vim.fn.mode():match("^[iR]") then
            vim.cmd("stopinsert")
        end
    end

    local function close_editor()
        stop_insert_mode()

        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end

        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, {
                force = true,
            })
        end

        vim.schedule(function()
            stop_insert_mode()

            if opts.on_close then
                opts.on_close()
            end
        end)
    end

    local function cancel_editor()
        local next_note = current_note()

        if next_note == previous then
            close_editor()
            return
        end

        vim.ui.input({
            prompt = "Discard session " .. slot .. " note changes? Type y to confirm: ",
        }, function(answer)
            if answer == "y" or answer == "Y" then
                close_editor()
            else
                vim.schedule(function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_set_current_win(win)
                        vim.cmd("startinsert")
                    end
                end)
            end
        end)
    end

    local function save_editor()
        local next_note = current_note()

        if next_note == previous then
            close_editor()
            return
        end

        vim.ui.input({
            prompt = "Update session " .. slot .. " note? Type y to confirm: ",
        }, function(answer)
            if answer ~= "y" and answer ~= "Y" then
                return
            end

            metadata = read_metadata(slot)
            metadata.slot = slot
            metadata.note = next_note

            write_metadata(slot, metadata)
            if opts.notify ~= false then
                vim.notify("Updated session " .. slot .. " note")
            end
            close_editor()

            if opts.on_update then
                opts.on_update()
            end

            vim.schedule(function()
                stop_insert_mode()
            end)
        end)
    end

    vim.keymap.set({ "n", "i" }, "<Esc>", cancel_editor, {
        buffer = buf,
        silent = true,
        desc = "Cancel session note edit",
    })

    vim.keymap.set("n", "<CR>", save_editor, {
        buffer = buf,
        silent = true,
        desc = "Save session note",
    })

    vim.keymap.set({ "n", "i" }, "<C-s>", save_editor, {
        buffer = buf,
        silent = true,
        desc = "Save session note",
    })

    vim.cmd("startinsert")
end

function M.note(slot, opts)
    open_note_editor(slot, opts)
end

function M.name(slot, opts)
    edit_metadata_field(slot, "name", "name", opts)
end

function M.delete(slot, force, opts)
    opts = opts or {}
    slot = known_slot_id(slot)

    if slot == nil then
        vim.notify("Session slot is not known.", vim.log.levels.ERROR)
        return
    end

    if not force then
        vim.ui.input({
            prompt = "Delete session " .. slot .. "? Type y to confirm: ",
        }, function(answer)
            if answer == "y" or answer == "Y" then
                M.delete(slot, true, opts)
            elseif opts.on_cancel then
                opts.on_cancel()
            end
        end)

        return
    end

    local removed = false

    if vim.fn.filereadable(session_path(slot)) == 1 then
        vim.fn.delete(session_path(slot))
        removed = true
    end

    if vim.fn.filereadable(metadata_path(slot)) == 1 then
        vim.fn.delete(metadata_path(slot))
        removed = true
    end

    if removed then
        vim.notify("Deleted session " .. slot)

        if active_session_slot == slot then
            active_session_slot = nil
        end

        if opts.on_update then
            opts.on_update()
        end
    else
        vim.notify("Session " .. slot .. " is already empty.", vim.log.levels.WARN)

        if opts.on_cancel then
            opts.on_cancel()
        end
    end
end

local function slot_entry(slot)
    local metadata = read_metadata(slot)
    local path = session_path(slot)
    local exists = session_exists(slot)
    local configured = configured_slot_lookup()[slot] == true
    local modified_at = file_mtime(path)
    local saved_at = metadata.saved_at

    if not saved_at and modified_at then
        saved_at = os.date("%Y-%m-%d %H:%M:%S", modified_at)
    end

    local cwd = metadata.cwd or ""
    local name = metadata.name or ""
    local note = metadata.note or ""
    local files = metadata.files or {}
    local terminals = metadata.terminals or {}
    local tree = metadata.tree or {}
    local status = exists and "Saved session" or "Empty"
    local summary = note

    if exists and name ~= "" then
        summary = name
    end

    if summary == "" and #files > 0 then
        summary = table.concat(first_files(files, 2), ", ")
    end

    if summary == "" then
        summary = exists and cwd or ""
    end

    return {
        slot = slot,
        exists = exists,
        configured = configured,
        saved_at = saved_at,
        cwd = cwd,
        name = name,
        note = note,
        files = files,
        terminal_count = #terminals,
        tree_visible = tree.visible == true,
        path = path,
        label = exists
            and string.format(
                "[%s] %s%s: %s",
                slot,
                configured and "" or "! ",
                status,
                summary
            )
            or string.format("[%s] %s%s", slot, configured and "" or "! ", status),
        ordinal = table.concat({
            tostring(slot),
            status,
            configured and "configured" or "unlisted",
            saved_at or "",
            cwd,
            name,
            note,
            table.concat(files, " "),
        }, " "),
    }
end

local function preview_lines(entry)
    local title = "Session " .. entry.slot

    if entry.name ~= "" then
        title = title .. " - " .. entry.name
    end

    local lines = {
        title,
        "",
        "Status: " .. (entry.exists and "saved" or "empty"),
        "Slot: " .. (entry.configured and "configured" or "unlisted"),
        "Saved: " .. (entry.saved_at or "-"),
        "Cwd: " .. (entry.cwd ~= "" and entry.cwd or "-"),
        "Terminals: " .. entry.terminal_count,
        "Tree: " .. (entry.tree_visible and "visible" or "hidden"),
    }

    if not entry.configured then
        table.insert(lines, "Hint: add this slot to session_slot_ids or move it to a configured slot.")
    end

    table.insert(lines, "")
    table.insert(lines, "Files:")

    if #entry.files == 0 then
        table.insert(lines, "  -")
    else
        for _, file in ipairs(first_files(entry.files, 30)) do
            table.insert(lines, "  " .. file)
        end

        if #entry.files > 30 then
            table.insert(lines, "  ... +" .. (#entry.files - 30) .. " more")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Note:")

    if entry.note == "" then
        table.insert(lines, "  -")
    else
        table.insert(lines, "")
        table.insert(lines, "")

        for _, line in ipairs(split_lines(entry.note)) do
            table.insert(lines, line)
        end
    end

    return lines
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
