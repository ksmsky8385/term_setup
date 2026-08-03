return {
    "nvim-lualine/lualine.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        local terminal = require("config.terminal")
        local window_picker = require("config.window_picker")
        local picker_exclude = {
            filetype = {
                "NvimTree",
                "notify",
            },
        }

        local function is_labeled_window(win)
            return window_picker.label_for_window(win, picker_exclude) ~= ""
        end

        local function window_label()
            local current = vim.g.statusline_winid or vim.api.nvim_get_current_win()

            if is_labeled_window(current) then
                return "[" .. window_picker.label_for_window(current, picker_exclude) .. "]"
            end

            return ""
        end

        local function status_filetype()
            local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
            local buf = vim.api.nvim_win_get_buf(win)
            return vim.bo[buf].filetype
        end

        local function is_agentic_chat()
            return status_filetype() == "AgenticChat"
        end

        local function is_agentic_input()
            return status_filetype() == "AgenticInput"
        end

        local function is_agentic_status_buffer()
            return is_agentic_chat() or is_agentic_input()
        end

        local function agentic_usage(state)
            local used = state and state:get_context_used()
            local size = state and state:get_context_size()
            local used_raw = state and state:get_context_used_raw()
            local size_raw = state and state:get_context_size_raw()

            if
                used == nil
                or size == nil
                or used_raw == nil
                or size_raw == nil
                or size_raw <= 0
            then
                return nil
            end

            local percent = math.max(
                0,
                math.min(
                    100,
                    math.floor(used_raw / size_raw * 100 + 0.5)
                )
            )

            return {
                used = used,
                size = size,
                percent = percent,
            }
        end

        local function agentic_session_state()
            local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
            local tab = vim.api.nvim_win_get_tabpage(win)
            local registry = require("agentic.session_registry")
            local session = registry.sessions[tab]
            return session and session.session_state
        end

        local function agentic_status_name()
            local state = agentic_session_state()
            local name

            if is_agentic_chat() then
                local model = state
                        and (state:get_model_name() or state:get_model_id())
                    or "unknown"
                local thought_level = state
                    and (
                        state:get_thought_level_name()
                        or state:get_thought_level_id()
                    )

                if thought_level and thought_level ~= "" then
                    model = string.format("%s (%s)", model, thought_level)
                end

                name = model
            else
                local usage = agentic_usage(state)

                if usage then
                    local warning = usage.percent > 80 and " " or ""
                    name = string.format(
                        "%s%s/%s (%d%%%%)",
                        warning,
                        usage.used,
                        usage.size,
                        usage.percent
                    )
                else
                    name = "-/- (-%%)"
                end
            end

            local label = window_label()

            return label ~= "" and (name .. " " .. label) or name
        end

        local function agentic_status_color()
            if not is_agentic_input() then
                return {}
            end

            local usage = agentic_usage(agentic_session_state())
            if not usage or usage.percent <= 80 then
                return {}
            end

            local highlight = vim.api.nvim_get_hl(0, {
                name = "DiagnosticWarn",
                link = false,
            })

            return highlight.fg
                    and { fg = string.format("#%06x", highlight.fg) }
                or {}
        end

        local function is_regular_status_buffer()
            return not terminal.is_status_terminal()
                and not is_agentic_status_buffer()
        end

        require("lualine").setup({
            options = {
                theme = "auto",
                section_separators = "",
                component_separators = "",
            },
            sections = {
                lualine_c = {
                    {
                        agentic_status_name,
                        cond = is_agentic_status_buffer,
                        color = agentic_status_color,
                        on_click = window_picker.focus_statusline_window,
                    },
                    {
                        window_label,
                        cond = function()
                            return not is_agentic_status_buffer()
                        end,
                        on_click = window_picker.focus_statusline_window,
                    },
                    terminal.status_name,
                    {
                        "filename",
                        cond = is_regular_status_buffer,
                    },
                },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {
                    {
                        agentic_status_name,
                        cond = is_agentic_status_buffer,
                        color = agentic_status_color,
                        on_click = window_picker.focus_statusline_window,
                    },
                    {
                        window_label,
                        cond = function()
                            return not is_agentic_status_buffer()
                        end,
                        on_click = window_picker.focus_statusline_window,
                    },
                    terminal.status_name,
                    {
                        "filename",
                        cond = is_regular_status_buffer,
                    },
                },
                lualine_x = { "location" },
                lualine_y = {},
                lualine_z = {},
            },
        })
    end,
}
