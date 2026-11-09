local M = {}
local generation = 0

local function registry()
    return package.loaded['agentic.session_registry']
end

function M.hide()
    generation = generation + 1
    local registered = registry()
    for _, session in pairs(registered and registered.sessions or {}) do
        if session.widget then session.widget:hide() end
    end
end

function M.snapshot()
    local result = {}
    local registered = registry()
    for _, session in pairs(registered and registered.sessions or {}) do
        local widget = session.widget
        local tab = widget and widget:get_visible_tab_id()
        if tab then
            local chat, input = widget.win_nrs.chat, widget.win_nrs.input
            local bottom = widget.current_position == 'bottom'
            local measure = bottom and vim.api.nvim_win_get_width or vim.api.nvim_win_get_height
            local chat_size = measure(chat)
            local input_size = input and vim.api.nvim_win_is_valid(input) and measure(input) or 0
            local editors = {}
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                if vim.api.nvim_win_get_config(win).relative == ''
                    and not vim.tbl_contains(vim.tbl_values(widget.win_nrs), win) then
                    editors[#editors + 1] = {
                        width = vim.api.nvim_win_get_width(win), height = vim.api.nvim_win_get_height(win),
                    }
                end
            end
            result[#result + 1] = {
                tab = vim.api.nvim_tabpage_get_number(tab), provider = session.provider_name,
                session_id = session.session_id, position = widget.current_position,
                width = vim.api.nvim_win_get_width(chat), height = vim.api.nvim_win_get_height(chat),
                input_ratio = input_size / math.max(1, chat_size + input_size),
                columns = vim.o.columns, lines = vim.o.lines, editors = editors,
            }
        end
    end
    return result
end

local function display(session, item, tab)
    if not vim.api.nvim_tabpage_is_valid(tab) or session._destroyed then return end
    local previous = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_tabpage(tab)
    local editors = vim.api.nvim_tabpage_list_wins(tab)
    local widget = session.widget
    widget.current_position = item.position or widget.current_position
    widget.size = {
        width = math.max(1, math.floor(item.width * vim.o.columns / item.columns)),
        height = math.max(1, math.floor(item.height * vim.o.lines / item.lines)),
    }
    require('agentic.session_registry').show_session(session.session_key, { focus_prompt = false })
    local input, chat = widget.win_nrs.input, widget.win_nrs.chat
    if input and chat and vim.api.nvim_win_is_valid(input) and vim.api.nvim_win_is_valid(chat) then
        local bottom = widget.current_position == 'bottom'
        local get = bottom and vim.api.nvim_win_get_width or vim.api.nvim_win_get_height
        local set = bottom and vim.api.nvim_win_set_width or vim.api.nvim_win_set_height
        local total = get(input) + get(chat)
        pcall(set, input, math.max(1, math.min(total - 1, math.floor(total * item.input_ratio + 0.5))))
    end
    local index = 0
    for _, win in ipairs(editors) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ''
            and not vim.tbl_contains(vim.tbl_values(widget.win_nrs), win) then
            index = index + 1
            local saved = (item.editors or {})[index]
            if saved then
                pcall(vim.api.nvim_win_set_width, win, math.max(1, math.floor(saved.width * vim.o.columns / item.columns)))
                pcall(vim.api.nvim_win_set_height, win, math.max(1, math.floor(saved.height * vim.o.lines / item.lines)))
            end
        end
    end
    if vim.api.nvim_win_is_valid(previous) then vim.api.nvim_set_current_win(previous) end
end

function M.restore(items)
    generation = generation + 1
    local token = generation
    if type(items) ~= 'table' or #items == 0 then return end
    local ok, lazy = pcall(require, 'lazy')
    if ok then lazy.load({ plugins = { 'agentic.nvim' } }) end
    local loaded, registered = pcall(require, 'agentic.session_registry')
    if not loaded then
        vim.notify('Agentic session windows could not be restored: plugin unavailable', vim.log.levels.WARN)
        return
    end
    local tabs = vim.api.nvim_list_tabpages()
    for _, item in ipairs(items) do
        local tab = tabs[item.tab]
        local function current() return token == generation and tab and vim.api.nvim_tabpage_is_valid(tab) end
        local function start(kind)
            if not current() then return end
            local previous = vim.api.nvim_get_current_win()
            vim.api.nvim_set_current_tabpage(tab)
            local session = registered.create(item.provider, { kind = kind, session_id = item.session_id })
            if vim.api.nvim_win_is_valid(previous) then vim.api.nvim_set_current_win(previous) end
            if not session then
                if kind == 'load' then start('new'); return end
                vim.notify('Agentic provider unavailable: ' .. tostring(item.provider), vim.log.levels.WARN)
                return
            end
            display(session, item, tab)
            session:on_session_ready(function()
                if current() then display(session, item, tab) end
            end, function()
                if kind == 'load' and current() then
                    vim.schedule(function()
                        if current() then
                            vim.notify('Saved Agentic conversation could not be loaded; starting a new session.', vim.log.levels.INFO)
                            start('new')
                        end
                    end)
                elseif current() then
                    vim.notify('Could not start a new Agentic session', vim.log.levels.WARN)
                end
            end)
        end
        if current() then
            local existing
            for _, session in pairs(registered.sessions) do
                if item.session_id and session.session_id == item.session_id
                    and session.provider_name == item.provider and not session._destroyed then
                    existing = session
                    break
                end
            end
            if existing then
                display(existing, item, tab)
            elseif not item.session_id then
                start('new')
            elseif item.provider == 'codex-acp' or item.provider == 'pi-acp' then
                require('config.agentic_archive').request({ action = 'availability', provider = item.provider,
                    session_id = item.session_id }, function(result)
                    if current() then start(result and result.available and 'load' or 'new') end
                end)
            else
                start('load')
            end
        end
    end
end

return M
