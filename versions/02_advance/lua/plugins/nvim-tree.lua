return {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local buffers = require("config.buffers")
        local swap = require("config.swap")
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

            local ok_empty, empty_buffers = pcall(require, "config.empty_buffers")

            if ok_empty then
                empty_buffers.cleanup({
                    keep = { vim.api.nvim_get_current_buf() },
                })
            end
        end

        local function restore_nvim_tree_highlights()
            local ok, appearance = pcall(require, "nvim-tree.appearance")

            if ok then
                appearance.highlight()
            end
        end

        local function close_preview()
            local closed = false

            if preview_win and vim.api.nvim_win_is_valid(preview_win) then
                vim.api.nvim_win_close(preview_win, true)
                closed = true
            end

            if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
                vim.api.nvim_buf_delete(preview_buf, { force = true })
                closed = true
            end

            preview_win = nil
            preview_buf = nil
            preview_tree_win = nil
            preview_path = nil

            return closed
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

        local function open_target_windows()
            local windows = {}

            for _, win in ipairs(window_picker.selectable_windows({
                filetype = {
                    "NvimTree",
                    "notify",
                },
            })) do
                if is_regular_window(win) then
                    local buf = vim.api.nvim_win_get_buf(win)

                    if vim.bo[buf].filetype ~= "notify" then
                        table.insert(windows, win)
                    end
                end
            end

            return windows
        end

        local function primary_open_window()
            return open_target_windows()[1]
        end

        local function show_preview(identifier, lines, filetype, opts)
            opts = opts or {}

            if
                preview_path == identifier
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

            if max_width < (opts.compact and 1 or 24) then
                vim.notify("Not enough room to preview file", vim.log.levels.WARN)
                return
            end

            local preview_width = math.min(90, max_width)
            local preview_height =
                math.max(8, math.min(vim.o.lines - tree_pos[1] - 4, 30))

            if opts.compact then
                local content_width = 1

                for _, line in ipairs(lines) do
                    content_width =
                        math.max(content_width, vim.fn.strdisplaywidth(line))
                end

                preview_width = math.min(content_width, max_width)
                preview_height = math.max(
                    1,
                    math.min(#lines, vim.o.lines - tree_pos[1] - 4)
                )
            end

            close_preview()
            preview_tree_win = tree_win
            preview_path = identifier

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

            if filetype then
                vim.bo[preview_buf].filetype = filetype
            end

            preview_win = vim.api.nvim_open_win(preview_buf, false, {
                relative = "editor",
                row = tree_pos[1],
                col = col,
                width = preview_width,
                height = preview_height,
                border = "rounded",
                style = "minimal",
            })

            vim.wo[preview_win].cursorline = true
            vim.wo[preview_win].number = false
            vim.wo[preview_win].relativenumber = false
            vim.wo[preview_win].wrap = opts.wrap == true
            vim.wo[preview_win].linebreak = opts.wrap == true
            vim.wo[preview_win].breakindent = opts.wrap == true

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

        local function open_preview()
            local node = api.tree.get_node_under_cursor()

            if not node then
                return
            end

            if not node.parent then
                show_preview("root:" .. node.absolute_path, {
                    node.absolute_path,
                }, nil, {
                    compact = true,
                })
                return
            end

            if node.type ~= "file" then
                api.node.open.edit(node)
                return
            end

            local ok, lines = pcall(vim.fn.readfile, node.absolute_path, "", 10000)

            if not ok then
                vim.notify("Can't preview this file", vim.log.levels.WARN)
                return
            end

            show_preview(
                "file:" .. node.absolute_path,
                lines,
                vim.filetype.match({ filename = node.absolute_path }),
                {
                    wrap = true,
                }
            )
        end

        local function close_preview_or_show_help()
            if close_preview() then
                return
            end

            show_preview("nvim-tree-help", {
                " nvim-tree shortcuts",
                "",
                " Navigation",
                " Tab          Preview path/file or toggle folder",
                " Enter / o    Open file or change cwd",
                " Double-click Same action as Tab/Enter by node type",
                " Ctrl+double   Run the opposite mouse action",
                " Esc          Close preview/help",
                "",
                " File management",
                " a            Create file or folder (folder: trailing /)",
                " r            Rename",
                " e            Rename basename",
                " x / c / p    Cut / copy / paste",
                " d            Move to trash",
                " D            Delete permanently",
                " y / Y        Copy name / relative path",
                " gy           Copy absolute path",
                "",
                " View",
                " H            Toggle dotfiles",
                " I            Toggle Git ignored files",
                " f / F        Start / clear live filter",
                " E / W        Expand / collapse all",
                " R            Refresh",
                " g?           Open full built-in help",
            }, nil, {
                compact = true,
            })
        end

        local function open_file_in_window(node, target_win)
            if not target_win or target_win == -1 then
                api.node.open.edit(node)
                return
            end

            local buf = swap.load_buffer(node.absolute_path, {
                win = target_win,
            })

            if not buf then
                return
            end

            local opened = buffers.open_buffer_in_window(buf, target_win, {
                delete_old_if_safe = true,
            })

            if opened and vim.api.nvim_win_is_valid(target_win) then
                vim.api.nvim_set_current_win(target_win)
            end
        end

        local function pick_open_window()
            return window_picker.pick_window({
                filetype = {
                    "NvimTree",
                    "notify",
                },
            })
        end

        local function pick_tab_for_window()
            if buffers.pick_tab_for_window then
                return buffers.pick_tab_for_window()
            end

            return true
        end

        local function open_file_in_split(node, split_cmd)
            if not pick_tab_for_window() then
                return
            end

            local target_win = pick_open_window()

            if not target_win or target_win == -1 then
                return
            end

            local ok_floating, floating = pcall(require, "config.floating")

            if ok_floating and floating.is_slot_window(target_win) then
                vim.notify("Floating slots do not support splits.", vim.log.levels.WARN)
                return
            end

            vim.api.nvim_set_current_win(target_win)
            window_picker.remember_window(target_win)
            vim.cmd(split_cmd)

            local split_win = vim.api.nvim_get_current_win()

            open_file_in_window(node, split_win)

            local ok_empty, empty_buffers = pcall(require, "config.empty_buffers")

            if ok_empty then
                empty_buffers.cleanup({
                    keep = { vim.api.nvim_win_get_buf(split_win) },
                })
            end
        end

        local function open_node(mode)
            local node = api.tree.get_node_under_cursor()

            if not node then
                return
            end

            if node.type ~= "file" then
                close_preview()
                local path = node.absolute_path

                if not node.parent then
                    path = vim.fs.dirname(path)
                end

                api.tree.change_root_to_node(node)
                require("config.workspace").change(path, {
                    notify = false,
                })
                return
            end

            close_preview()

            if mode == "pick" then
                if not pick_tab_for_window() then
                    return
                end

                local target_win = pick_open_window()

                if not target_win or target_win == -1 then
                    return
                end

                open_file_in_window(node, target_win)
                return
            end

            if mode == "split" then
                open_file_in_split(node, "rightbelow split")
                return
            end

            if mode == "vsplit" then
                open_file_in_split(node, "rightbelow vsplit")
                return
            end

            open_file_in_window(node, primary_open_window())
        end

        local function root_folder_label(path)
            local normalized_path = vim.fs.normalize(path)
            local home = vim.fs.normalize(vim.fn.expand("~"))

            if normalized_path == home then
                return vim.fs.basename(home)
            end

            if normalized_path == "/" then
                return "/"
            end

            return "../" .. vim.fs.basename(normalized_path)
        end

        local function focus_mouse_node()
            local mouse = vim.fn.getmousepos()

            if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
                return
            end

            if mouse.line < 1 then
                return
            end

            vim.api.nvim_set_current_win(mouse.winid)
            vim.api.nvim_win_set_cursor(mouse.winid, { mouse.line, 0 })
        end

        local function open_mouse(invert)
            focus_mouse_node()

            local node = api.tree.get_node_under_cursor()

            if not node then
                return
            end

            local preview_action = node.type ~= "file"

            if invert then
                preview_action = not preview_action
            end

            if preview_action then
                open_preview()
            else
                open_node()
            end
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
                    "<Tab>",
                    open_preview,
                    opts("Preview path/file or toggle directory")
                )

                vim.keymap.set(
                    "n",
                    "<CR>",
                    function()
                        open_node()
                    end,
                    opts("Open file or change tree root")
                )

                vim.keymap.set(
                    "n",
                    "o",
                    function()
                        open_node()
                    end,
                    opts("Open file or change tree root")
                )

                vim.keymap.set(
                    "n",
                    "<LeftMouse>",
                    focus_mouse_node,
                    opts("Select node")
                )

                vim.keymap.set(
                    "n",
                    "<2-LeftMouse>",
                    function()
                        open_mouse(false)
                    end,
                    opts("Open node by type")
                )

                vim.keymap.set(
                    "n",
                    "<C-LeftMouse>",
                    focus_mouse_node,
                    opts("Select node")
                )

                vim.keymap.set(
                    "n",
                    "<C-2-LeftMouse>",
                    function()
                        open_mouse(true)
                    end,
                    opts("Open node with inverse action")
                )

                vim.keymap.set(
                    "n",
                    "w",
                    function()
                        open_node("pick")
                    end,
                    opts("Open with window picker")
                )

                vim.keymap.set(
                    "n",
                    "s",
                    function()
                        open_node("split")
                    end,
                    opts("Open in picked horizontal split")
                )

                vim.keymap.set(
                    "n",
                    "v",
                    function()
                        open_node("vsplit")
                    end,
                    opts("Open in picked vertical split")
                )

                vim.keymap.set(
                    { "n", "x" },
                    "d",
                    api.fs.trash,
                    opts("Move to trash")
                )

                vim.keymap.set(
                    { "n", "x" },
                    "D",
                    api.fs.remove,
                    opts("Delete permanently")
                )

                vim.keymap.set(
                    "n",
                    "<Esc>",
                    close_preview_or_show_help,
                    opts("Close preview or show file tree help")
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
                root_folder_label = root_folder_label,
            },

            filters = {
                dotfiles = false,
            },

            trash = {
                cmd = "gio trash",
            },

            actions = {
                open_file = {
                    window_picker = {
                        enable = false,
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
