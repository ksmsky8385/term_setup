local sidebar_settings = require("config.sidebar_settings")

local function highlight_color(name, key, fallback)
    local ok, highlight = pcall(vim.api.nvim_get_hl, 0, {
        name = name,
        link = false,
    })

    if ok and type(highlight) == "table" and highlight[key] then
        return highlight[key]
    end

    return fallback
end

local function lighten(color, amount)
    local red = math.floor(color / 0x10000) % 0x100
    local green = math.floor(color / 0x100) % 0x100
    local blue = color % 0x100

    local function channel(value)
        return math.floor(value + (0xff - value) * amount + 0.5)
    end

    return channel(red) * 0x10000
        + channel(green) * 0x100
        + channel(blue)
end

local function apply_agentic_prompt_highlights()
    local normal_bg = highlight_color("Normal", "bg", 0x1f1f1f)
    local normal_fg = highlight_color("Normal", "fg", 0xcccccc)
    local accent = highlight_color(
        "DiagnosticInfo",
        "fg",
        highlight_color("Identifier", "fg", 0x75beff)
    )
    local input_line_bg = lighten(lighten(normal_bg, 0.07), 0.045)

    vim.api.nvim_set_hl(0, "AgenticPromptNormal", {
        fg = normal_fg,
        bg = normal_bg,
    })
    vim.api.nvim_set_hl(0, "AgenticPromptCursorLine", {
        fg = normal_fg,
        bg = normal_bg,
    })
    vim.api.nvim_set_hl(0, "AgenticPromptMarker", {
        fg = accent,
        bg = normal_bg,
        bold = true,
    })
    vim.api.nvim_set_hl(0, "AgenticTitle", {
        fg = normal_fg,
        bg = input_line_bg,
        bold = false,
    })
end

local function agentic_session_cwd(session_state)
    local cwd = session_state and session_state._config_session_cwd
        or vim.g.current_workspace_root
        or vim.uv.cwd()

    return cwd and vim.fn.fnamemodify(cwd, ":~") or ""
end

local function agentic_cwd_header(_parts, session_state)
    return agentic_session_cwd(session_state)
end

local function track_agentic_session_cwd()
    local SessionManager = require("agentic.session_manager")
    local usage_store = require("config.agentic_config").usage

    if SessionManager._config_tracks_session_cwd then
        return
    end

    local original_new_session = SessionManager.new_session
    local original_load_acp_session = SessionManager.load_acp_session
    local original_on_session_update = SessionManager._on_session_update

    local function provider_name(session)
        return session.agent
            and session.agent.provider_config
            and session.agent.provider_config.name
            or "unknown"
    end

    local function remember_cwd(session)
        if session.session_state then
            session.session_state._config_session_cwd = vim.fn.getcwd()
        end
    end

    SessionManager.new_session = function(self, opts)
        remember_cwd(self)
        return original_new_session(self, opts)
    end

    SessionManager.load_acp_session = function(
        self,
        session_id,
        title,
        timestamp
    )
        remember_cwd(self)
        local result = original_load_acp_session(
            self,
            session_id,
            title,
            timestamp
        )
        local usage = usage_store.get(provider_name(self), session_id)

        if usage and self.session_state then
            self.session_state:set_usage(usage)
            self.widget:schedule_header_refresh()
        end

        return result
    end

    SessionManager._on_session_update = function(self, update)
        original_on_session_update(self, update)

        if update.sessionUpdate ~= "usage_update" then
            return
        end

        local active_session_id =
            self.session_id or self._restoring_session_id
        local used = self.session_state:get_context_used_raw()
        local size = self.session_state:get_context_size_raw()

        usage_store.set(
            provider_name(self),
            active_session_id,
            used,
            size
        )
    end

    SessionManager._config_tracks_session_cwd = true
end

local function focus_regular_editor_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if
            vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == ""
        then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if
                vim.bo[buf].buftype == ""
                and filetype ~= "NvimTree"
                and filetype ~= "FloatingSlot"
                and filetype ~= "notify"
                and not filetype:match("^Agentic")
            then
                vim.api.nvim_set_current_win(win)
                return true
            end
        end
    end

    return false
end

local function allow_dashboard_as_fallback()
    local ChatWidget = require("agentic.ui.chat_widget")

    if ChatWidget._config_dashboard_fallback then
        return
    end

    local original_find = ChatWidget.find_first_non_widget_window

    ChatWidget.find_first_non_widget_window = function(self)
        local win = original_find(self)

        if win then
            return win
        end

        for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(self.tab_page_id)) do
            if
                vim.api.nvim_win_is_valid(candidate)
                and vim.api.nvim_win_get_config(candidate).relative == ""
            then
                local buf = vim.api.nvim_win_get_buf(candidate)

                if vim.bo[buf].filetype == "alpha" then
                    return candidate
                end
            end
        end

        return nil
    end

    ChatWidget._config_dashboard_fallback = true
end

local function refresh_headers_after_show()
    local ChatWidget = require("agentic.ui.chat_widget")

    if ChatWidget._config_refresh_headers_after_show then
        return
    end

    local original_show = ChatWidget.show
    ChatWidget.show = function(self, opts)
        local should_focus_prompt = opts == nil or opts.focus_prompt ~= false

        original_show(self, opts)

        -- Reopening the widget creates new windows and WidgetLayout initially
        -- renders their headers without session_state. Refresh once the layout
        -- exists so the chat header keeps its model and usage information.
        self:schedule_header_refresh()

        if should_focus_prompt then
            vim.schedule(function()
                local input_win = self.win_nrs.input

                if
                    input_win
                    and vim.api.nvim_win_is_valid(input_win)
                    and vim.api.nvim_get_current_win() == input_win
                then
                    vim.cmd("stopinsert")
                end
            end)
        end
    end

    ChatWidget._config_refresh_headers_after_show = true
end

return {
    "carlos-algms/agentic.nvim",
    init = function()
        apply_agentic_prompt_highlights()

        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = apply_agentic_prompt_highlights,
            desc = "Adapt the Agentic prompt panel to the active colorscheme",
        })

        vim.api.nvim_create_autocmd("DirChanged", {
            callback = function()
                local ok, registry = pcall(
                    require,
                    "agentic.session_registry"
                )
                if not ok then
                    return
                end

                for _, session in pairs(registry.sessions) do
                    if session and session.widget then
                        session.widget:schedule_header_refresh()
                    end
                end
            end,
            desc = "Refresh the Agentic prompt cwd header",
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "Agentic*",
            callback = function(args)
                local leader = vim.g.mapleader or "\\"
                local blocked_leader_mappings = {
                    leader .. "h",
                }

                for _, lhs in ipairs(blocked_leader_mappings) do
                    vim.keymap.set({ "n", "x", "s" }, lhs, "<Nop>", {
                        buffer = args.buf,
                        silent = true,
                        nowait = true,
                        desc = "Protect Agentic buffer from navigation action",
                    })
                end

                vim.keymap.set("n", leader .. "?", function()
                    require("config.about").toggle_floating()
                end, {
                    buffer = args.buf,
                    silent = true,
                    nowait = true,
                    desc = "Toggle About Neovim",
                })

                vim.keymap.set({ "n", "x", "s" }, leader .. "q", function()
                    require("agentic").close()
                end, {
                    buffer = args.buf,
                    silent = true,
                    nowait = true,
                    desc = "Hide all Agentic windows",
                })

                vim.keymap.set({ "n", "x", "s" }, leader .. "Q", function()
                    require("agentic.session_registry").destroy_session()
                end, {
                    buffer = args.buf,
                    silent = true,
                    nowait = true,
                    desc = "Close all Agentic windows and destroy the session",
                })

                vim.keymap.set("n", leader .. "e", function()
                    focus_regular_editor_window()
                    vim.cmd("TreeToggle")
                end, {
                    buffer = args.buf,
                    silent = true,
                    desc = "Toggle file tree from the editor layout",
                })

                if vim.bo[args.buf].filetype == "AgenticInput" then
                    vim.keymap.set("i", "<S-CR>", "<CR>", {
                        buffer = args.buf,
                        silent = true,
                        desc = "Insert newline in Agentic prompt",
                    })
                end
            end,
            desc = "Protect Agentic buffers from conflicting navigation actions",
        })
    end,
    opts = {
        provider = "codex-acp",
        windows = {
            position = "right",
            width = sidebar_settings.get("agentic_width"),
            height = "30%",
            chat = {
                buffer_name = "Agentic",
            },
            input = {
                buffer_name = "󰦨 Prompt",
                height = sidebar_settings.get("agentic_height"),
                win_opts = {
                    cursorline = true,
                    signcolumn = "yes:1",
                    statuscolumn = "%#AgenticPromptMarker#%{v:lnum == 1 && v:virtnum == 0 ? '> ' : '  '}",
                    winhighlight = table.concat({
                        "Normal:AgenticPromptNormal",
                        "NormalNC:AgenticPromptNormal",
                        "CursorLine:AgenticPromptCursorLine",
                        "EndOfBuffer:AgenticPromptNormal",
                        "SignColumn:AgenticPromptNormal",
                    }, ","),
                },
            },
            code = {
                buffer_name = "Code",
            },
            files = {
                buffer_name = "Files",
            },
            diagnostics = {
                buffer_name = "Diagnostics",
            },
            todos = {
                buffer_name = "Tasks",
            },
        },
        diff_preview = {
            enabled = true,
            layout = "split",
            center_on_navigate_hunks = true,
        },
        headers = {
            chat = function()
                return ""
            end,
            input = agentic_cwd_header,
        },
        keymaps = {
            prompt = {
                submit = {
                    {
                        "<CR>",
                        mode = { "n", "i" },
                    },
                    {
                        "<C-s>",
                        mode = { "n", "v", "i" },
                    },
                },
            },
        },
    },
    config = function(_, opts)
        allow_dashboard_as_fallback()
        track_agentic_session_cwd()
        refresh_headers_after_show()
        require("agentic").setup(opts)
        apply_agentic_prompt_highlights()
    end,
    keys = {
        {
            "<leader>aa",
            function()
                require("agentic").toggle({
                    auto_add_to_context = false,
                })
            end,
            mode = { "n", "v" },
            desc = "Toggle Agentic chat",
        },
        {
            "<leader>ac",
            function()
                require("agentic").add_selection_or_file_to_context()
            end,
            mode = { "n", "v" },
            desc = "Add file or selection to Agentic",
        },
        {
            "<leader>an",
            function()
                require("agentic").new_session({
                    auto_add_to_context = false,
                })
            end,
            mode = { "n", "v" },
            desc = "Start new Agentic session",
        },
        {
            "<leader>ar",
            function()
                require("config.agentic_config").show()
            end,
            mode = { "n", "v" },
            desc = "Restore Agentic session",
        },
        {
            "<leader>al",
            function()
                require("agentic").rotate_layout({ "right", "bottom" })
            end,
            mode = { "n", "v" },
            desc = "Rotate Agentic layout",
        },
        {
            "<leader>as",
            function()
                require("agentic").switch_provider()
            end,
            mode = { "n", "v" },
            desc = "Switch Agentic provider",
        },
        {
            "<leader>ad",
            function()
                require("agentic").add_current_line_diagnostics()
            end,
            mode = "n",
            desc = "Add current diagnostic to Agentic",
        },
        {
            "<leader>aD",
            function()
                require("agentic").add_buffer_diagnostics()
            end,
            mode = "n",
            desc = "Add buffer diagnostics to Agentic",
        },
    },
}
