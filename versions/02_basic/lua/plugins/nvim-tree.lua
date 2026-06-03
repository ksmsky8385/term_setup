return {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local terminal = require("config.terminal")
        local window_picker = require("config.window_picker")
        local api = require("nvim-tree.api")
        local preview_win
        local preview_buf
        local preview_tree_win
        local preview_path

        local function is_regular_window(win)
            if not vim.api.nvim_win_is_valid(win) then
                return false
            end

            if vim.api.nvim_win_get_config(win).relative ~= "" then
                return false
            end

            local buf = vim.api.nvim_win_get_buf(win)

            return vim.bo[buf].filetype ~= "NvimTree"
        end

        local function regular_window_count()
            local count = 0

            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_regular_window(win) then
                    count = count + 1
                end
            end

            return count
        end

        local function replace_duplicate_tree_window()
            if vim.bo.filetype ~= "NvimTree" then
                return
            end

            local tree_win = api.tree.winid()
            local current_win = vim.api.nvim_get_current_win()

            if not tree_win or current_win == tree_win then
                return
            end

            vim.cmd("enew")
        end

        local function restore_nvim_tree_highlights()
            local ok, appearance = pcall(require, "nvim-tree.appearance")

            if ok then
                appearance.highlight()
            end
        end

        local function close_preview()
            if preview_win and vim.api.nvim_win_is_valid(preview_win) then
                vim.api.nvim_win_close(preview_win, true)
            end

            if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
                vim.api.nvim_buf_delete(preview_buf, { force = true })
            end

            preview_win = nil
            preview_buf = nil
            preview_tree_win = nil
            preview_path = nil
        end

        local function focus_preview()
            if preview_win and vim.api.nvim_win_is_valid(preview_win) then
                vim.api.nvim_set_current_win(preview_win)
                return
            end

            vim.cmd("wincmd l")
        end

        local function focus_tree()
            if preview_tree_win and vim.api.nvim_win_is_valid(preview_tree_win) then
                vim.api.nvim_set_current_win(preview_tree_win)
            end
        end

        local function open_preview()
            local node = api.tree.get_node_under_cursor()

            if not node then
                return
            end

            if node.type ~= "file" then
                api.node.open.edit(node)
                return
            end

            if
                preview_path == node.absolute_path
                and preview_win
                and vim.api.nvim_win_is_valid(preview_win)
            then
                close_preview()
                return
            end

            local tree_win = vim.api.nvim_get_current_win()
            local tree_pos = vim.api.nvim_win_get_position(tree_win)
            local tree_width = vim.api.nvim_win_get_width(tree_win)
            local col = tree_pos[2] + tree_width + 1
            local max_width = vim.o.columns - col - 2

            if max_width < 24 then
                vim.notify("Not enough room to preview file", vim.log.levels.WARN)
                return
            end

            local ok, lines = pcall(vim.fn.readfile, node.absolute_path, "", 10000)

            if not ok then
                vim.notify("Can't preview this file", vim.log.levels.WARN)
                return
            end

            close_preview()
            preview_tree_win = tree_win
            preview_path = node.absolute_path

            preview_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(preview_buf, "nvim-tree-preview")
            vim.bo[preview_buf].bufhidden = "wipe"
            vim.bo[preview_buf].buftype = "nofile"
            vim.bo[preview_buf].buflisted = false
            vim.bo[preview_buf].modifiable = true
            vim.bo[preview_buf].swapfile = false
            vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
            vim.bo[preview_buf].modifiable = false
            vim.bo[preview_buf].readonly = true

            local filetype = vim.filetype.match({ filename = node.absolute_path })

            if filetype then
                vim.bo[preview_buf].filetype = filetype
            end

            preview_win = vim.api.nvim_open_win(preview_buf, false, {
                relative = "editor",
                row = tree_pos[1],
                col = col,
                width = math.min(90, max_width),
                height = math.max(8, math.min(vim.o.lines - tree_pos[1] - 4, 30)),
                border = "rounded",
                style = "minimal",
            })

            vim.wo[preview_win].cursorline = true
            vim.wo[preview_win].number = false
            vim.wo[preview_win].relativenumber = false
            vim.wo[preview_win].wrap = false

            vim.keymap.set("n", "<C-Left>", focus_tree, {
                buffer = preview_buf,
                noremap = true,
                silent = true,
                desc = "Focus file tree",
            })

            vim.keymap.set("n", "<C-h>", focus_tree, {
                buffer = preview_buf,
                noremap = true,
                silent = true,
                desc = "Focus file tree",
            })

            vim.keymap.set("n", "<Tab>", focus_tree, {
                buffer = preview_buf,
                noremap = true,
                silent = true,
                desc = "Focus file tree",
            })

            vim.keymap.set("n", "<Esc>", close_preview, {
                buffer = preview_buf,
                noremap = true,
                silent = true,
                desc = "Close file preview",
            })
        end

        local function open_node()
            local node = api.tree.get_node_under_cursor()

            if not node then
                return
            end

            if node and node.type == "file" then
                close_preview()
            end

            api.node.open.edit(node)
        end

        require("nvim-tree").setup({
            sync_root_with_cwd = true,
            respect_buf_cwd = true,

            on_attach = function(bufnr)
                api.config.mappings.default_on_attach(bufnr)

                local function opts(desc)
                    return {
                        buffer = bufnr,
                        noremap = true,
                        silent = true,
                        nowait = true,
                        desc = desc,
                    }
                end

                vim.keymap.set(
                    "n",
                    "<leader>t",
                    terminal.pick_terminal,
                    opts("Pick terminal")
                )

                vim.keymap.set(
                    "n",
                    "<Tab>",
                    open_preview,
                    opts("Preview file")
                )

                vim.keymap.set(
                    "n",
                    "<CR>",
                    open_node,
                    opts("Open")
                )

                vim.keymap.set(
                    "n",
                    "<Esc>",
                    close_preview,
                    opts("Close file preview")
                )

                vim.keymap.set(
                    "n",
                    "<C-Right>",
                    focus_preview,
                    opts("Focus file preview")
                )

                vim.keymap.set(
                    "n",
                    "<C-l>",
                    focus_preview,
                    opts("Focus file preview")
                )
            end,

            view = {
                width = 30,
            },

            renderer = {
                group_empty = true,
            },

            filters = {
                dotfiles = false,
            },

            actions = {
                open_file = {
                    window_picker = {
                        enable = true,
                        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
                        picker = function()
                            return window_picker.pick_window({
                                filetype = {
                                    "NvimTree",
                                    "notify",
                                },
                                buftype = {
                                    "terminal",
                                },
                            })
                        end,

                        exclude = {
                            filetype = {
                                "NvimTree",
                                "notify",
                            },
                            buftype = {
                                "terminal",
                            },
                        },
                    },
                },
            },
        })

        restore_nvim_tree_highlights()

        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = restore_nvim_tree_highlights,
        })

        vim.api.nvim_create_autocmd("QuitPre", {
            callback = function()
                if
                    vim.bo.filetype ~= "NvimTree"
                    and regular_window_count() == 1
                    and api.tree.is_visible()
                then
                    api.tree.close()
                end
            end,
        })

        vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
            callback = replace_duplicate_tree_window,
        })

        vim.keymap.set("n", "<leader>e", ":TreeToggle<CR>", {
            noremap = true,
            silent = true,
            desc = "Toggle file tree",
        })
    end,
}
