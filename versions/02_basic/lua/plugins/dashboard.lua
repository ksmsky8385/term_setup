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

        local function make_header()
            local cwd = vim.g.current_workspace_root or vim.fn.getcwd()

            return {
                "",
                "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
                "████╗  ██║██║   ██║██║████╗ ████║",
                "██╔██╗ ██║██║   ██║██║██╔████╔██║",
                "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
                "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ " .. version_text,
                "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
                "",
                "root: " .. cwd,
                "",
            }
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