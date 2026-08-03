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
    local prompt_bg = lighten(normal_bg, 0.07)

    vim.api.nvim_set_hl(0, "AgenticPromptNormal", {
        fg = normal_fg,
        bg = prompt_bg,
    })
    vim.api.nvim_set_hl(0, "AgenticPromptCursorLine", {
        fg = normal_fg,
        bg = lighten(prompt_bg, 0.045),
    })
    vim.api.nvim_set_hl(0, "AgenticPromptMarker", {
        fg = accent,
        bg = prompt_bg,
        bold = true,
    })
end

local function agentic_chat_header(parts, session_state)
    if not session_state then
        return parts.title
    end

    local model = session_state:get_model_name() or "unknown"
    local thought_level = session_state:get_thought_level_name()
        or session_state:get_thought_level_id()

    if thought_level and thought_level ~= "" then
        model = string.format("%s (%s)", model, thought_level)
    end

    local segments = {
        session_state:get_provider_name(),
        model,
        session_state:get_mode_name(),
    }
    local visible_segments = {}

    for _, segment in ipairs(segments) do
        if segment and segment ~= "" then
            visible_segments[#visible_segments + 1] = segment
        end
    end

    local header = string.format(
        "%s | %s",
        parts.title,
        table.concat(visible_segments, " - ")
    )
    local used = session_state:get_context_used()
    local size = session_state:get_context_size()

    if used ~= nil and size ~= nil then
        header = header .. string.format(" (%s/%s)", used, size)
    end

    local cost = session_state:get_cost_amount_raw()
    if cost ~= nil and cost ~= 0 then
        local amount = session_state:get_cost_amount() or ""
        local currency = session_state:get_cost_currency()
        header = header
            .. " "
            .. (currency and (currency .. " ") or "")
            .. amount
    end

    return header
end

local function agentic_input_header(parts, _session_state)
    local segments = { parts.title }

    local cwd = vim.g.current_workspace_root or vim.uv.cwd()
    if cwd and cwd ~= "" then
        segments[#segments + 1] = vim.fn.fnamemodify(cwd, ":~")
    end

    return table.concat(segments, " | ")
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
                buffer_name = "Prompt",
                win_opts = {
                    cursorline = true,
                    signcolumn = "yes:1",
                    statuscolumn = "%#AgenticPromptMarker#%{v:lnum == 1 ? '> ' : '  '}",
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
            chat = agentic_chat_header,
            input = agentic_input_header,
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
        refresh_headers_after_show()
        require("agentic").setup(opts)
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
                require("config.agentic_session_restore").show()
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
