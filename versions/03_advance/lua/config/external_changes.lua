local M = {}

local pending = {}
local sequence = 0
local directory_watchers = {}

local function reloadable(buf)
    return type(buf) == "number"
        and vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) ~= ""
        and not vim.bo[buf].modified
end

local function watchable(buf)
    return type(buf) == "number"
        and vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function check_buffer(buf)
    if not reloadable(buf) then return end
    sequence = sequence + 1
    local token = sequence
    pending[buf] = token

    vim.defer_fn(function()
        if pending[buf] ~= token then return end
        pending[buf] = nil
        if not reloadable(buf) then return end
        pcall(vim.cmd, "silent checktime " .. buf)
    end, 40)
end

local function check_visible_buffers()
    local seen = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if not seen[buf] then
                seen[buf] = true
                check_buffer(buf)
            end
        end
    end
end

local function visible_directories()
    local directories = {}

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local name = vim.api.nvim_buf_get_name(buf)

            if watchable(buf) and name ~= "" then
                directories[vim.fs.dirname(name)] = true
            end
        end
    end

    return directories
end

local function stop_watcher(directory)
    local watcher = directory_watchers[directory]
    if not watcher then return end

    watcher:stop()
    watcher:close()
    directory_watchers[directory] = nil
end

local function sync_directory_watchers()
    local wanted = visible_directories()

    for directory in pairs(directory_watchers) do
        if not wanted[directory] then stop_watcher(directory) end
    end

    for directory in pairs(wanted) do
        if not directory_watchers[directory] then
            local watcher = vim.uv.new_fs_event()
            local started = watcher:start(directory, {}, function(err)
                if not err then vim.schedule(check_visible_buffers) end
            end)

            if started then
                directory_watchers[directory] = watcher
            else
                watcher:close()
            end
        end
    end
end

local function schedule_watcher_sync()
    vim.schedule(sync_directory_watchers)
end

function M.setup()
    vim.opt.autoread = true
    local group = vim.api.nvim_create_augroup("ConfigExternalFileChanges", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "BufWinEnter" }, {
        group = group,
        callback = function(args)
            check_buffer(args.buf or vim.api.nvim_get_current_buf())
            schedule_watcher_sync()
        end,
    })

    vim.api.nvim_create_autocmd({ "BufWinLeave", "WinClosed" }, {
        group = group,
        callback = schedule_watcher_sync,
    })

    vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "TermClose" }, {
        group = group,
        callback = function()
            vim.schedule(check_visible_buffers)
        end,
    })

    sync_directory_watchers()

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        once = true,
        callback = function()
            for directory in pairs(directory_watchers) do
                stop_watcher(directory)
            end
        end,
    })
end

return M
