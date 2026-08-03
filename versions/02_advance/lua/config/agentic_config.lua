local M = {}

local function select_session(items, on_choice)
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
            prompt_title = "Agentic sessions",
            results_title = "Enter restore",
            preview_title = "Session info",
        }
    else
        picker_opts = themes.get_dropdown({
            previewer = false,
            width = 0.78,
            height = 0.55,
            prompt_title = "Agentic sessions",
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
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local entry = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    on_choice(entry and entry.value or nil)
                end)
                return true
            end,
        })
        :find()
end

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

local function restore(current_session, choice)
    local has_messages = current_session.session_id ~= nil
        and current_session.chat_history ~= nil
        and #current_session.chat_history.messages > 0

    local function load()
        current_session:load_acp_session(
            choice.session_id,
            choice.title,
            choice.updated_at
        )
        current_session.widget:show()
    end

    if not has_messages then
        load()
        return
    end

    vim.ui.select({
        "Cancel",
        "Clear current session and restore",
    }, {
        prompt = "Current session has messages. What would you like to do?",
    }, function(answer)
        if answer == "Clear current session and restore" then
            load()
        end
    end)
end

function M.show()
    local registry = require("agentic.session_registry")

    registry.get_session_for_tab_page(nil, function(current_session)
        local cwd = vim.fn.getcwd()
        local provider_name = current_session.agent.provider_config.name
            or "Unknown provider"

        current_session.agent:when_ready(function()
            current_session.agent:list_sessions(cwd, function(result, err)
                vim.schedule(function()
                    if err or not result then
                        vim.notify(
                            "Failed to list Agentic sessions",
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
                            updated_at = date,
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
                            restore(current_session, choice)
                        end
                    end)
                end)
            end)
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
