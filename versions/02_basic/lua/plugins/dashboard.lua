return {
    "goolord/alpha-nvim",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        local version = vim.version()
        local version_text = string.format(
            "ver. %d.%d.%d",
            version.major,
            version.minor,
            version.patch
        )

        local ascii_header = {
            "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
            "████╗  ██║██║   ██║██║████╗ ████║",
            "██╔██╗ ██║██║   ██║██║██╔████╔██║",
            "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ " .. version_text,
            "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
        }

        local function get_header_width()
            local width = 0

            for _, line in ipairs(ascii_header) do
                width = math.max(width, vim.fn.strdisplaywidth(line))
            end

            return width
        end

        local function wrap_path(path, max_width)
            local lines = {}
            local prefix = "root: "
            local indent = "      "
            local current = prefix

            for part in string.gmatch(path, "[^/]+") do
                local next_part = current .. "/" .. part

                if vim.fn.strdisplaywidth(next_part) > max_width then
                    table.insert(lines, current)
                    current = indent .. "/" .. part
                else
                    current = next_part
                end
            end

            table.insert(lines, current)

            return lines
        end

        local function make_header()
            local cwd = vim.g.current_workspace_root or vim.fn.getcwd()
            local header_width = get_header_width()
            local path_lines = wrap_path(cwd, header_width)

            local header = { "" }

            vim.list_extend(header, ascii_header)

            table.insert(header, "")

            vim.list_extend(header, path_lines)

            table.insert(header, "")

            return header
        end

        local dashboard_buttons = {
            dashboard.button("e", "   New file", ":ene <BAR> startinsert<CR>"),
            dashboard.button("f", "   Find file", ":Telescope find_files<CR>"),
            dashboard.button("g", "󰊄   Search text", ":Telescope live_grep<CR>"),
            dashboard.button("w", "   Change workspace", ":WorkspacePick<CR>"),
            dashboard.button("t", "   Toggle tree", ":TreeToggle<CR>"),
            dashboard.button("s", "   Settings", ":MainSettings<CR>"),
            dashboard.button("a", "   About Neovim", ":AboutNeovim<CR>"),
        }

        local function dashboard_button_rows()
            local rows = {}
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

            for line_nr, line in ipairs(lines) do
                for _, button in ipairs(dashboard_buttons) do
                    if string.find(line, button.val, 1, true) then
                        table.insert(rows, line_nr)
                        break
                    end
                end
            end

            return rows
        end

        local function move_dashboard_cursor(delta)
            local rows = dashboard_button_rows()

            if #rows == 0 then
                return
            end

            local current_row = vim.api.nvim_win_get_cursor(0)[1]
            local target = nil

            for idx, row in ipairs(rows) do
                if row == current_row then
                    local next_idx = idx + delta

                    if next_idx < 1 then
                        next_idx = #rows
                    elseif next_idx > #rows then
                        next_idx = 1
                    end

                    target = rows[next_idx]
                    break
                end
            end

            if not target then
                if delta > 0 then
                    for _, row in ipairs(rows) do
                        if row > current_row then
                            target = row
                            break
                        end
                    end

                    target = target or rows[1]
                else
                    for idx = #rows, 1, -1 do
                        if rows[idx] < current_row then
                            target = rows[idx]
                            break
                        end
                    end

                    target = target or rows[#rows]
                end
            end

            vim.api.nvim_win_set_cursor(0, { target, 0 })
            alpha.move_cursor(vim.api.nvim_get_current_win())
        end

        dashboard.section.header.val = make_header()
        dashboard.section.buttons.val = dashboard_buttons
        dashboard.section.footer.val = {}

        alpha.setup(dashboard.opts)

        vim.api.nvim_create_autocmd("User", {
            pattern = "AlphaReady",
            callback = function()
                local opts = {
                    buffer = true,
                    silent = true,
                }

                vim.keymap.set("n", "j", function()
                    move_dashboard_cursor(1)
                end, opts)
                vim.keymap.set("n", "<Down>", function()
                    move_dashboard_cursor(1)
                end, opts)
                vim.keymap.set("n", "k", function()
                    move_dashboard_cursor(-1)
                end, opts)
                vim.keymap.set("n", "<Up>", function()
                    move_dashboard_cursor(-1)
                end, opts)
            end,
        })

        vim.api.nvim_create_user_command("DashboardHome", function()
            dashboard.section.header.val = make_header()
            alpha.setup(dashboard.opts)
            vim.cmd("Alpha")
        end, {})
    end,
}
