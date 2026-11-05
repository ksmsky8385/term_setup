local M = {}

-- Registry keys are session IDs, not tab handles. Resolve the buffer whose
-- statusline is being drawn, including inactive windows and retained sessions.
function M.state_for_window(win)
    if not vim.api.nvim_win_is_valid(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    for _, session in pairs(require("agentic.session_registry").sessions) do
        local buffers = session.widget and session.widget.buf_nrs or {}
        for _, candidate in pairs(buffers) do
            if candidate == buf then return session.session_state end
        end
    end
end

function M.remember_provider(data)
    if data.err or not data.session_id then return end
    local session = require("agentic.session_registry").sessions[data.session_key]
    if not session or session.session_id ~= data.session_id then return end
    local provider = session.provider_name
    if require("config.sidebar_settings").set("agentic_provider", provider) then
        require("agentic.config").provider = provider
    end
end

local function select_session(items, on_choice, opts)
    opts = opts or {}
    local ok_pickers, pickers = pcall(require, "telescope.pickers")
    local ok_finders, finders = pcall(require, "telescope.finders")
    local ok_config, telescope_config =
        pcall(require, "telescope.config")
    local ok_actions, actions = pcall(require, "telescope.actions")
    local ok_state, action_state = pcall(require, "telescope.actions.state")
    local ok_themes, themes = pcall(require, "telescope.themes")
    local ok_previewers, previewers = pcall(require, "telescope.previewers")

    if
        not ok_pickers
        or not ok_finders
        or not ok_config
        or not ok_actions
        or not ok_state
        or not ok_themes
        or not ok_previewers
    then
        vim.ui.select(items, {
            prompt = "Restore Agentic session:",
            format_item = function(item)
                return item.display
            end,
        }, on_choice)
        return
    end

    local has_preview = vim.o.columns >= 140 and vim.o.lines >= 35
    local picker_opts

    if has_preview then
        picker_opts = {
            width = 0.9,
            height = 0.75,
            layout_strategy = "horizontal",
            layout_config = {
                preview_width = 0.5,
            },
            prompt_title = opts.archived and "Agentic archives" or "Agentic sessions",
            results_title = opts.help or "Enter restore",
            preview_title = "Session info",
        }
    else
        picker_opts = themes.get_dropdown({
            previewer = false,
            width = 0.78,
            height = 0.55,
            prompt_title = opts.archived and "Agentic archives" or "Agentic sessions",
            results_title = false,
        })
    end

    pickers
        .new(picker_opts, {
            finder = finders.new_table({
                results = items,
                entry_maker = function(item)
                    return {
                        value = item,
                        display = item.display,
                        ordinal = item.display,
                    }
                end,
            }),
            sorter = telescope_config.values.generic_sorter({}),
            previewer = has_preview
                    and previewers.new_buffer_previewer({
                        define_preview = function(self, entry)
                            local item = entry.value
                            vim.api.nvim_buf_set_lines(
                                self.state.bufnr,
                                0,
                                -1,
                                false,
                                item.preview_lines
                            )
                            vim.bo[self.state.bufnr].filetype = "markdown"
                        end,
                    })
                or false,
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local entry = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    on_choice(entry and entry.value or nil)
                end)
                if opts.attach_mappings then opts.attach_mappings(prompt_bufnr, map) end
                return true
            end,
        })
        :find()
end

M.select_session = select_session

local function preview_lines(
    title,
    display_title,
    provider_name,
    updated_at,
    session_id
)
    local lines = {
        "# Session",
        "",
        "**Provider:** " .. provider_name,
        "",
        "**Updated:** " .. updated_at,
        "",
        "**Title:** " .. display_title,
        "",
        "**Session ID:** " .. session_id,
    }
    local environment = type(title) == "string"
            and title:match(
                "<environment_info>%s*(.-)%s*</environment_info>"
            )
        or nil

    if environment and environment ~= "" then
        vim.list_extend(lines, {
            "",
            "---",
            "",
            "# Environment at session start",
            "",
        })
        vim.list_extend(lines, vim.split(environment, "\n", {
            plain = true,
            trimempty = true,
        }))
    end

    return lines
end

local function brief_title(title)
    title = type(title) == "string" and title or ""
    title = title:gsub("<environment_info>.-</environment_info>", " ")
    title = title:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""

    if title == "" then
        return "(no title)"
    end

    if vim.fn.strchars(title) > 72 then
        return vim.fn.strcharpart(title, 0, 69) .. "..."
    end

    return title
end

function M.session_item(item, provider)
    local value = vim.deepcopy(item)
    local date = (item.updated_at or "unknown date"):sub(1, 16):gsub("T", " ")
    local title = brief_title(item.title)
    value.display = string.format("[%s]  %s  %s", provider, date, title)
    value.preview_lines = preview_lines(item.title, title, provider, date, item.session_id)
    if item.path then
        vim.list_extend(value.preview_lines, { "", "**File:** " .. item.path })
    end
    return value
end

local function restore(context, choice)
    local registry = require("agentic.session_registry")
    local existing = registry.find_by_acp_session_id(choice.session_id, context.agent)
    if not existing and not (context.agent.agent_capabilities or {}).loadSession then
        vim.notify("Agent does not support loading sessions", vim.log.levels.WARN)
        return
    end

    registry.choose_session_lifecycle(context.source, "Restore session:", function(destroy_source)
        local target = registry.replace(context.source, context.provider_name, {
            kind = "load",
            session_id = choice.session_id,
            title = choice.title,
            timestamp = choice.updated_at,
        }, {
            agent = context.agent,
            retain_source = context.source ~= nil and not destroy_source,
        })
        if target then
            target:on_session_ready(function()
                require("config.agentic_limits").on_open({
                    session_key = target.session_key,
                    session_id = target.session_id,
                })
            end, function() end)
        end
    end)
end

function M.show()
    local registry = require("agentic.session_registry")

    local source = registry.current()
    local provider_name = source and source.provider_name or require("agentic.config").provider
    local agent = source and source.agent
        or require("agentic.acp.agent_instance").get_instance(provider_name)
    if not agent then
        return
    end
    local context = { source = source, provider_name = provider_name, agent = agent }
    local cwd = vim.fn.getcwd()

    agent:when_ready(function()
        if provider_name == "codex-acp" or provider_name == "pi-acp" then
            require("config.agentic_archive").show(context, restore)
            return
        end
        agent:list_sessions(cwd, function(result, err)
            vim.schedule(function()
                if err or not result then
                    vim.notify(
                        "Failed to list Agentic sessions: " .. (err and err.message or "unknown error"),
                        vim.log.levels.WARN
                    )
                    return
                end

                local items = {}
                for _, session in ipairs(result.sessions or {}) do
                    local date = session.updatedAt
                            and session.updatedAt
                                :sub(1, 16)
                                :gsub("T", " ")
                        or "unknown date"
                    local display_title = brief_title(session.title)

                    items[#items + 1] = {
                        display = string.format(
                            "[%s]  %s  %s",
                            provider_name,
                            date,
                            display_title
                        ),
                        session_id = session.sessionId,
                        title = session.title,
                        preview_title = display_title,
                        updated_at = session.updatedAt,
                        preview_lines = preview_lines(
                            session.title,
                            display_title,
                            provider_name,
                            date,
                            session.sessionId
                        ),
                    }
                end

                if #items == 0 then
                    vim.notify(
                        "No saved Agentic sessions found",
                        vim.log.levels.INFO
                    )
                    return
                end

                select_session(items, function(choice)
                    if choice then
                        restore(context, choice)
                    end
                end)
            end)
        end)
    end, function(err)
        vim.schedule(function()
            vim.notify(
                "Failed to list Agentic sessions: " .. (err.message or "provider unavailable"),
                vim.log.levels.WARN
            )
        end)
    end)
end

M.usage = {}

local usage_save_path = vim.fn.stdpath("state") .. "/agentic-usage.json"
local usage_values

local function load_usage()
    if usage_values then
        return
    end

    usage_values = {}

    if vim.fn.filereadable(usage_save_path) ~= 1 then
        return
    end

    local ok, decoded = pcall(
        vim.json.decode,
        table.concat(vim.fn.readfile(usage_save_path), "\n")
    )

    if ok and type(decoded) == "table" then
        usage_values = decoded
    end
end

local function usage_cache_key(provider, session_id)
    return string.format("%s:%s", provider or "unknown", session_id)
end

local function save_usage()
    local dir = vim.fn.fnamemodify(usage_save_path, ":h")
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ vim.json.encode(usage_values) }, usage_save_path)
end

function M.usage.get(provider, session_id)
    if not session_id or session_id == "" then
        return nil
    end

    load_usage()
    local usage = usage_values[usage_cache_key(provider, session_id)]

    if
        type(usage) ~= "table"
        or type(usage.used) ~= "number"
        or type(usage.size) ~= "number"
    then
        return nil
    end

    return {
        used = usage.used,
        size = usage.size,
    }
end

function M.usage.set(provider, session_id, used, size)
    if
        not session_id
        or session_id == ""
        or type(used) ~= "number"
        or type(size) ~= "number"
    then
        return
    end

    load_usage()
    usage_values[usage_cache_key(provider, session_id)] = {
        used = used,
        size = size,
    }
    save_usage()
end

return M
