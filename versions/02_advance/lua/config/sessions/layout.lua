local M = {}
local empty_buffers = require("config.empty_buffers")

local VERSION = 1

local function valid_window(win)
    return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function valid_buffer(buf)
    return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function is_empty_buffer(buf)
    return valid_buffer(buf)
        and not vim.bo[buf].buflisted
        and vim.api.nvim_buf_get_name(buf) == ""
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].filetype == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local function create_empty_buffer()
    local buf = vim.api.nvim_create_buf(false, false)

    vim.bo[buf].buflisted = false
    vim.bo[buf].swapfile = false

    return buf
end

local function current_window_cwd(win)
    local ok, cwd = pcall(vim.api.nvim_win_call, win, function()
        return vim.fn.getcwd()
    end)

    if ok then
        return cwd
    end

    return vim.fn.getcwd()
end

local function window_view(win)
    local current_win = vim.api.nvim_get_current_win()
    local ok_set = pcall(vim.api.nvim_set_current_win, win)

    if not ok_set then
        return nil
    end

    local ok_view, view = pcall(vim.fn.winsaveview)

    if valid_window(current_win) and current_win ~= win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    if ok_view then
        return view
    end

    return nil
end

local buffer_descriptor

local function dashboard_descriptor(win)
    local previous = valid_window(win) and vim.w[win].config_dashboard_previous_buf or nil
    local descriptor = {
        kind = "dashboard",
    }

    if valid_buffer(previous) then
        descriptor.previous = buffer_descriptor(previous)
    end

    return descriptor
end

buffer_descriptor = function(buf, win)
    if not valid_buffer(buf) then
        return {
            kind = "empty",
        }
    end

    local filetype = vim.bo[buf].filetype
    local buftype = vim.bo[buf].buftype
    local name = vim.api.nvim_buf_get_name(buf)

    if vim.b[buf].config_about_neovim then
        return dashboard_descriptor(win)
    end

    if filetype == "NvimTree" then
        return {
            kind = "tree",
            width = valid_window(win) and vim.api.nvim_win_get_width(win) or nil,
        }
    end

    if filetype == "alpha" then
        return dashboard_descriptor(win)
    end

    if buftype == "terminal" then
        return {
            kind = "terminal",
            cwd = valid_window(win) and current_window_cwd(win) or vim.fn.getcwd(),
            shell = vim.o.shell,
        }
    end

    if is_empty_buffer(buf) then
        return {
            kind = "empty",
        }
    end

    if buftype == "" and name ~= "" then
        local cursor = valid_window(win) and vim.api.nvim_win_get_cursor(win) or nil

        return {
            kind = "file",
            path = name,
            cursor = cursor,
            view = valid_window(win) and window_view(win) or nil,
        }
    end

    return {
        kind = "scratch",
        filetype = filetype,
        buftype = buftype,
        listed = vim.bo[buf].buflisted == true,
    }
end

local function window_geometry(win)
    local row = 0
    local col = 0
    local ok_pos, pos = pcall(vim.api.nvim_win_get_position, win)

    if ok_pos and type(pos) == "table" then
        row = pos[1] or row
        col = pos[2] or col
    end

    return {
        row = row,
        col = col,
        width = vim.api.nvim_win_get_width(win),
        height = vim.api.nvim_win_get_height(win),
    }
end

local function window_picker_order(win)
    local ok, picker = pcall(require, "config.window_picker")

    if not ok or type(picker.existing_window_order) ~= "function" then
        return nil
    end

    return picker.existing_window_order(win)
end

local function serialize_layout(node, descriptors, current_win, next_leaf)
    local node_type = node[1]

    if node_type == "leaf" then
        local win = node[2]
        local leaf = next_leaf.value

        next_leaf.value = next_leaf.value + 1

        if valid_window(win) then
            local buf = vim.api.nvim_win_get_buf(win)

            descriptors[tostring(leaf)] = vim.tbl_extend(
                "force",
                {
                    leaf = leaf,
                    current = win == current_win,
                    geometry = window_geometry(win),
                    window_order = window_picker_order(win),
                },
                buffer_descriptor(buf, win)
            )
        end

        return {
            type = "leaf",
            leaf = leaf,
        }
    end

    local children = {}

    for _, child in ipairs(node[2] or {}) do
        table.insert(children, serialize_layout(child, descriptors, current_win, next_leaf))
    end

    return {
        type = node_type,
        children = children,
    }
end

function M.snapshot()
    local current_tab = vim.api.nvim_get_current_tabpage()
    local current_win = vim.api.nvim_get_current_win()
    local tabs = {}
    local tabpages = vim.api.nvim_list_tabpages()
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    for tab_index, tab in ipairs(tabpages) do
        vim.api.nvim_set_current_tabpage(tab)

        if ok_picker and type(window_picker.selectable_windows) == "function" then
            window_picker.selectable_windows({
                filetype = {
                    "FloatingTerminal",
                    "NvimTree",
                    "notify",
                },
            })
        end

        local descriptors = {}
        local next_leaf = {
            value = 1,
        }

        table.insert(tabs, {
            index = tab_index,
            current = tab == current_tab,
            layout = serialize_layout(vim.fn.winlayout(), descriptors, current_win, next_leaf),
            windows = descriptors,
        })
    end

    if vim.api.nvim_tabpage_is_valid(current_tab) then
        pcall(vim.api.nvim_set_current_tabpage, current_tab)
    end

    if valid_window(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    return {
        version = VERSION,
        columns = vim.o.columns,
        lines = vim.o.lines,
        tabs = tabs,
    }
end

local function ensure_tab_count(count)
    while #vim.api.nvim_list_tabpages() < count do
        vim.cmd("tabnew")
    end

    while #vim.api.nvim_list_tabpages() > count do
        local tabs = vim.api.nvim_list_tabpages()

        vim.api.nvim_set_current_tabpage(tabs[#tabs])
        pcall(vim.cmd, "tabclose!")
    end
end

local function reset_current_tab()
    pcall(vim.cmd, "silent! only!")
    vim.api.nvim_win_set_buf(0, create_empty_buffer())
end

local function split_for_node_type(node_type)
    if node_type == "row" then
        vim.cmd("rightbelow vsplit")
    else
        vim.cmd("rightbelow split")
    end
end

local build_node

local function tail(children)
    local items = {}

    for index = 2, #children do
        table.insert(items, children[index])
    end

    return items
end

local function build_sequence(children, node_type, win, leaf_windows)
    if #children == 0 then
        return
    end

    if #children == 1 then
        build_node(children[1], win, leaf_windows)
        return
    end

    vim.api.nvim_set_current_win(win)
    split_for_node_type(node_type)

    local rest_win = vim.api.nvim_get_current_win()

    build_node(children[1], win, leaf_windows)
    build_sequence(tail(children), node_type, rest_win, leaf_windows)
end

build_node = function(node, win, leaf_windows)
    if not node or not valid_window(win) then
        return
    end

    if node.type == "leaf" then
        leaf_windows[tostring(node.leaf)] = win
        return
    end

    build_sequence(node.children or {}, node.type, win, leaf_windows)
end

local function restore_file(win, descriptor)
    if
        type(descriptor.path) ~= "string"
        or descriptor.path == ""
        or vim.fn.filereadable(descriptor.path) == 0
    then
        vim.api.nvim_win_set_buf(win, create_empty_buffer())
        return
    end

    local buf = vim.fn.bufadd(descriptor.path)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true
    vim.api.nvim_win_set_buf(win, buf)

    if type(descriptor.cursor) == "table" then
        pcall(vim.api.nvim_win_set_cursor, win, descriptor.cursor)
    end

    if type(descriptor.view) == "table" then
        local current_win = vim.api.nvim_get_current_win()

        if pcall(vim.api.nvim_set_current_win, win) then
            pcall(vim.fn.winrestview, descriptor.view)
        end

        if valid_window(current_win) and current_win ~= win then
            pcall(vim.api.nvim_set_current_win, current_win)
        end
    end
end

local function restore_terminal(win, descriptor)
    local current_win = vim.api.nvim_get_current_win()

    vim.api.nvim_set_current_win(win)

    if type(descriptor.cwd) == "string" and vim.fn.isdirectory(descriptor.cwd) == 1 then
        pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(descriptor.cwd))
    end

    local ok, terminal = pcall(require, "config.terminal")

    if ok then
        pcall(terminal.create_buffer_terminal)
    else
        pcall(vim.cmd, "terminal")
    end

    if valid_window(current_win) and current_win ~= vim.api.nvim_get_current_win() then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function restore_tree(win, descriptor)
    local current_win = vim.api.nvim_get_current_win()
    local ok, api = pcall(require, "nvim-tree.api")

    vim.api.nvim_set_current_win(win)

    if ok then
        pcall(api.tree.open, {
            current_window = true,
            focus = false,
        })
    else
        local buf = create_empty_buffer()

        vim.bo[buf].filetype = "NvimTree"
        vim.api.nvim_win_set_buf(win, buf)
    end

    if type(descriptor.width) == "number" then
        pcall(vim.cmd, "vertical resize " .. descriptor.width)
    end

    if valid_window(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function restore_dashboard(win, descriptor)
    local current_win = vim.api.nvim_get_current_win()
    local previous_buf = nil

    if type(descriptor.previous) == "table" and descriptor.previous.kind == "file" then
        local path = descriptor.previous.path

        if type(path) == "string" and path ~= "" then
            previous_buf = vim.fn.bufadd(path)
            vim.fn.bufload(previous_buf)
            vim.bo[previous_buf].buflisted = true
        end
    end

    vim.api.nvim_set_current_win(win)

    local ok = pcall(vim.cmd, "DashboardHome")

    if not ok then
        local buf = create_empty_buffer()

        vim.bo[buf].filetype = "alpha"
        vim.api.nvim_win_set_buf(win, buf)
    end

    if valid_buffer(previous_buf) then
        vim.w[vim.api.nvim_get_current_win()].config_dashboard_previous_buf = previous_buf
    end

    if type(descriptor.previous) == "table" then
        vim.w[vim.api.nvim_get_current_win()].config_dashboard_previous_descriptor = descriptor.previous
    end

    if valid_window(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function restore_scratch(win, descriptor)
    local buf = create_empty_buffer()

    if descriptor.kind == "scratch" then
        vim.bo[buf].buflisted = descriptor.listed == true
        vim.bo[buf].buftype = descriptor.buftype or ""
        vim.bo[buf].filetype = descriptor.filetype or ""
    end

    vim.api.nvim_win_set_buf(win, buf)
end

local function restore_window_buffer(win, descriptor)
    if not valid_window(win) or type(descriptor) ~= "table" then
        return
    end

    local kind = descriptor.kind

    if kind == "file" then
        restore_file(win, descriptor)
    elseif kind == "terminal" then
        restore_terminal(win, descriptor)
    elseif kind == "tree" then
        restore_tree(win, descriptor)
    elseif kind == "dashboard" then
        restore_dashboard(win, descriptor)
    else
        restore_scratch(win, descriptor)
    end
end

local function restore_non_terminal_buffers(leaf_windows, windows)
    local terminals = {}

    for leaf, descriptor in pairs(windows or {}) do
        local win = leaf_windows[leaf]

        if descriptor.kind == "terminal" then
            if valid_window(win) then
                vim.api.nvim_win_set_buf(win, create_empty_buffer())
                table.insert(terminals, {
                    win = win,
                    descriptor = descriptor,
                })
            end
        else
            restore_window_buffer(win, descriptor)
        end
    end

    return terminals
end

local function restore_terminal_buffers(terminals)
    for _, item in ipairs(terminals) do
        if valid_window(item.win) then
            restore_terminal(item.win, item.descriptor)
        end
    end
end

local function restore_window_orders(leaf_windows, windows)
    local ok, picker = pcall(require, "config.window_picker")

    if not ok or type(picker.set_window_order) ~= "function" then
        return
    end

    for leaf, descriptor in pairs(windows or {}) do
        local order = descriptor.window_order

        if type(order) == "number" and valid_window(leaf_windows[leaf]) then
            picker.set_window_order(leaf_windows[leaf], order)
        end
    end
end

local function restore_sizes(leaf_windows, windows)
    for leaf, win in pairs(leaf_windows) do
        local descriptor = windows[leaf]
        local geometry = descriptor and descriptor.geometry

        if valid_window(win) and type(geometry) == "table" then
            if type(geometry.height) == "number" then
                pcall(vim.api.nvim_set_current_win, win)
                pcall(vim.cmd, "resize " .. geometry.height)
            end

            if type(geometry.width) == "number" then
                pcall(vim.api.nvim_set_current_win, win)
                pcall(vim.cmd, "vertical resize " .. geometry.width)
            end
        end
    end
end

local function restore_tab(tab)
    reset_current_tab()

    local leaf_windows = {}

    build_node(tab.layout, vim.api.nvim_get_current_win(), leaf_windows)

    local terminals = restore_non_terminal_buffers(leaf_windows, tab.windows or {})

    restore_sizes(leaf_windows, tab.windows or {})
    restore_terminal_buffers(terminals)
    restore_window_orders(leaf_windows, tab.windows or {})

    for leaf, descriptor in pairs(tab.windows or {}) do
        if descriptor.current and valid_window(leaf_windows[leaf]) then
            pcall(vim.api.nvim_set_current_win, leaf_windows[leaf])
            break
        end
    end
end

local function cleanup_hidden_empty_buffers()
    empty_buffers.cleanup()
end

function M.restore(snapshot)
    if type(snapshot) ~= "table" or snapshot.version ~= VERSION or type(snapshot.tabs) ~= "table" then
        return false
    end

    ensure_tab_count(#snapshot.tabs)

    local tabs = vim.api.nvim_list_tabpages()
    local current_tab_index = 1

    for index, tab_snapshot in ipairs(snapshot.tabs) do
        if vim.api.nvim_tabpage_is_valid(tabs[index]) then
            vim.api.nvim_set_current_tabpage(tabs[index])
            restore_tab(tab_snapshot)

            if tab_snapshot.current then
                current_tab_index = index
            end
        end
    end

    tabs = vim.api.nvim_list_tabpages()

    if tabs[current_tab_index] and vim.api.nvim_tabpage_is_valid(tabs[current_tab_index]) then
        vim.api.nvim_set_current_tabpage(tabs[current_tab_index])
    end

    cleanup_hidden_empty_buffers()

    return true
end

return M
