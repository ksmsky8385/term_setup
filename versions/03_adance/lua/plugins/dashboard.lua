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

        dashboard.section.header.val = make_header()

        dashboard.section.buttons.val = {
            dashboard.button("e", "   New file", ":ene <BAR> startinsert<CR>"),
            dashboard.button("f", "   Find file", ":Telescope find_files<CR>"),
            dashboard.button("g", "󰊄   Search text", ":Telescope live_grep<CR>"),
            dashboard.button("w", "   Change workspace", ":WorkspacePick<CR>"),
            dashboard.button("t", "   Toggle tree", ":TreeToggle<CR>"),
            dashboard.button("s", "   Settings", ":MainSettings<CR>"),
            dashboard.button("a", "   About Neovim", ":AboutNeovim<CR>"),
        }

        dashboard.section.footer.val = {}

        alpha.setup(dashboard.opts)

        vim.api.nvim_create_user_command("DashboardHome", function()
            dashboard.section.header.val = make_header()
            alpha.setup(dashboard.opts)
            vim.cmd("Alpha")
        end, {})
    end,
}
