local M = {}
local script = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h') .. '/scripts/agentic_sessions.py'

function M.request(params, callback)
    if vim.fn.executable('python3') ~= 1 then
        callback(nil, 'Session archive management requires python3')
        return
    end
    vim.system({ 'python3', script }, { text = true, stdin = vim.json.encode(params), timeout = 60000 }, function(result)
        vim.schedule(function()
            local ok, value = pcall(vim.json.decode, result.stdout or '')
            if not ok or result.code ~= 0 or value.error then
                callback(nil, ok and value.error or 'Session operation failed or timed out')
            else
                callback(value)
            end
        end)
    end)
end

-- Match the existing session save/overwrite/delete command-line prompt.
function M.confirm(message, callback)
    vim.ui.input({ prompt = message .. ' [Enter/y: confirm, n/Esc: cancel]: ' }, function(answer)
        callback(answer == '' or answer == 'y' or answer == 'Y')
    end)
end

function M.show(context, restore, archived)
    archived = archived == true
    local provider = context.provider_name
    M.request({ action = 'list', provider = provider, archived = archived,
        cwd = not archived and vim.fn.getcwd() or nil }, function(result, err)
        if err then vim.notify(err, vim.log.levels.ERROR); return end
        local actions = require('telescope.actions')
        local state = require('telescope.actions.state')
        local function reopen(mode)
            M.show(context, restore, mode)
        end
        local function mutate(item, action)
            if not item then return end
            local registry = require('agentic.session_registry')
            for _, session in pairs(registry.sessions) do
                if session.provider_name == provider and session.is_generating then
                    vim.notify('Stop the agent task before changing session files.', vim.log.levels.WARN)
                    reopen(archived)
                    return
                end
            end
            local verb = action == 'delete' and 'Permanently delete' or
                (action == 'archive' and 'Archive' or 'Unarchive')
            local scope = provider == 'codex-acp' and action ~= 'unarchive'
                and ' (including descendant sessions)' or ''
            M.confirm(verb .. ' selected session' .. scope .. '?', function(yes)
                if not yes then reopen(archived); return end
                -- Release any open view before moving its backing file.
                local keys = {}
                for key, session in pairs(registry.sessions) do
                    if session.provider_name == provider and session.session_id == item.session_id then
                        if session.is_generating then
                            vim.notify('Session is now generating; action cancelled.', vim.log.levels.WARN)
                            reopen(archived)
                            return
                        end
                        keys[#keys + 1] = key
                    end
                end
                for _, key in ipairs(keys) do registry.destroy(key) end
                M.request({ action = action, provider = provider, session_id = item.session_id, path = item.path }, function(_, failure)
                    if failure then vim.notify(failure, vim.log.levels.ERROR) end
                    reopen(archived)
                end)
            end)
        end
        local session_config = require('config.agentic_config')
        local items = {}
        for _, item in ipairs(result.items) do
            items[#items + 1] = session_config.session_item(item, provider)
        end
        session_config.select_session(items, function(item)
            if not item then return end
            if archived then
                vim.schedule(function() mutate(item, 'unarchive') end)
            else
                context.source = require('agentic.session_registry').current()
                restore(context, item)
            end
        end, {
            archived = archived,
            help = archived and 'Enter restore | C-r unarchive | C-x delete | C-o sessions'
                or 'Enter restore | C-a archive | C-o archives',
            attach_mappings = function(buf, map)
                local function selected(action)
                    local entry = state.get_selected_entry()
                    if not entry then return end
                    actions.close(buf)
                    vim.schedule(function() mutate(entry.value, action) end)
                end
                for _, mode in ipairs({ 'i', 'n' }) do
                    map(mode, '<C-o>', function()
                        actions.close(buf)
                        vim.schedule(function() reopen(not archived) end)
                    end)
                    if archived then
                        map(mode, '<C-r>', function() selected('unarchive') end)
                        map(mode, '<C-x>', function() selected('delete') end)
                    else
                        map(mode, '<C-a>', function() selected('archive') end)
                    end
                end
            end,
        })
    end)
end

return M
