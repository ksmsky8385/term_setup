return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },

    config = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local builtin = require("telescope.builtin")
        local floating = require("config.floating")
        local tree_settings = require("config.tree_settings")
        local find_files
        local live_grep

        local function is_nvim_tree()
            return vim.bo.filetype == "NvimTree"
        end

        local function search_current_word()
            if is_nvim_tree() then
                return
            end

            live_grep({
                default_text = vim.fn.expand("<cword>"),
            })
        end

        local function visual_selection()
            local register = "v"
            local old_value = vim.fn.getreg(register)
            local old_type = vim.fn.getregtype(register)

            vim.cmd([[noautocmd normal! "vy]])

            local text = vim.fn.getreg(register)

            vim.fn.setreg(register, old_value, old_type)

            return text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        end

        local function search_visual_selection()
            if is_nvim_tree() then
                return
            end

            local text = visual_selection()

            if text == "" then
                return
            end

            live_grep({
                default_text = text,
            })
        end

        local function entry_path(entry)
            return entry and (entry.path or entry.filename or entry.value)
        end

        local function open_entry_in_slot(prompt_bufnr, slot_id)
            local entry = action_state.get_selected_entry()
            local path = entry_path(entry)

            if not path then
                return
            end

            actions.close(prompt_bufnr)

            vim.schedule(function()
                if floating.open_file(path, {
                    slot_id = slot_id,
                }) then
                    if entry.lnum then
                        pcall(vim.api.nvim_win_set_cursor, 0, {
                            entry.lnum,
                            math.max((entry.col or 1) - 1, 0),
                        })
                    end
                end
            end)
        end

        local function slot_picker_opts(slot_id, opts)
            opts = opts or {}

            if slot_id == nil then
                return opts
            end

            local attach_mappings = opts.attach_mappings

            opts.attach_mappings = function(prompt_bufnr, map)
                if attach_mappings and attach_mappings(prompt_bufnr, map) == false then
                    return false
                end

                local open = function()
                    open_entry_in_slot(prompt_bufnr, slot_id)
                end

                map("i", "<CR>", open)
                map("n", "<CR>", open)

                return true
            end

            return opts
        end

        local function sync_tree_filter(name)
            local ok, api = pcall(require, "nvim-tree.api")
            if not ok then return end
            if name == "dotfiles" then
                pcall(api.filter.dotfiles.toggle)
            elseif name == "git_ignored" then
                pcall(api.filter.git.ignored.toggle)
            end
        end

        local function visibility_picker_opts(opts, kind)
            opts = vim.tbl_extend("force", {}, opts or {})
            local show_hidden = not tree_settings.get("dotfiles")
            local show_ignored = not tree_settings.get("git_ignored")
            if kind == "files" then
                opts.hidden = show_hidden
                opts.no_ignore = show_ignored
            else
                local previous_args = opts.additional_args
                opts.additional_args = function(...)
                    local args = type(previous_args) == "function" and (previous_args(...) or {})
                        or vim.deepcopy(previous_args or {})
                    if show_hidden then table.insert(args, "--hidden") end
                    if show_ignored then table.insert(args, "--no-ignore") end
                    return args
                end
            end
            local previous_attach = opts.attach_mappings

            opts.attach_mappings = function(prompt_bufnr, map)
                if previous_attach and previous_attach(prompt_bufnr, map) == false then return false end
                local function toggle(name)
                    return function()
                        local prompt = action_state.get_current_line()
                        tree_settings.toggle(name)
                        sync_tree_filter(name)
                        actions.close(prompt_bufnr)
                        vim.schedule(function()
                            if kind == "files" then
                                find_files({ default_text = prompt })
                            else
                                live_grep({ default_text = prompt })
                            end
                        end)
                    end
                end
                map("i", "H", toggle("dotfiles"))
                map("n", "H", toggle("dotfiles"))
                map("i", "I", toggle("git_ignored"))
                map("n", "I", toggle("git_ignored"))
                return true
            end
            return opts
        end

        find_files = function(opts)
            builtin.find_files(slot_picker_opts(floating.window_slot_id(), visibility_picker_opts(opts, "files")))
        end

        live_grep = function(opts)
            builtin.live_grep(slot_picker_opts(floating.window_slot_id(), visibility_picker_opts(opts, "grep")))
        end

        vim.api.nvim_create_user_command("FloatingFindFiles", function()
            find_files()
        end, {})

        vim.api.nvim_create_user_command("FloatingLiveGrep", function()
            live_grep()
        end, {})

        telescope.setup({
            defaults = {
                mappings = {
                    i = {
                        ["<Esc>"] = function()
                            vim.cmd("stopinsert")
                        end,
                    },
                    n = {
                        ["<Esc>"] = actions.close,
                        ["<leader>?"] = function()
                            require("config.about").toggle_floating()
                        end,
                    },
                },
            },
        })

        vim.keymap.set("n", "<leader>ff", find_files, {
            desc = "Find files",
        })

        vim.keymap.set("n", "<leader>fg", live_grep, {
            desc = "Live grep",
        })

        vim.keymap.set("n", "<leader>sw", search_current_word, {
            desc = "Search current word",
        })

        vim.keymap.set("v", "<leader>ss", search_visual_selection, {
            desc = "Search selected text",
        })

        vim.keymap.set("n", "<leader>fh", builtin.help_tags, {
            desc = "Help tags",
        })
    end,
}
