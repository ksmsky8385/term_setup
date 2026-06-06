local M = {}

local function hl(name)
    local ok, value = pcall(vim.api.nvim_get_hl, 0, {
        name = name,
        link = false,
    })

    if ok and type(value) == "table" then
        return value
    end

    return {}
end

local function first_color(key, names, fallback)
    for _, name in ipairs(names) do
        local value = hl(name)[key]

        if value then
            return value
        end
    end

    return fallback
end

local function apply_highlights()
    local normal_bg = first_color("bg", { "Normal", "TabLineFill" }, nil)
    local inactive_fg = first_color("fg", { "Normal", "TabLine", "StatusLine" }, 0xffffff)
    local inactive_bg = first_color("bg", { "TabLine", "Normal" }, normal_bg)
    local fill_fg = first_color("fg", { "TabLineFill", "Comment" }, 0x666666)
    local active_bg = first_color("fg", { "Identifier" }, 0x7aa2f7)
    local active_fg = normal_bg or 0x111111

    vim.api.nvim_set_hl(0, "ConfigTabActive", {
        fg = active_fg,
        bg = active_bg,
        bold = true,
    })
    vim.api.nvim_set_hl(0, "ConfigTabFill", {
        fg = fill_fg,
        bg = normal_bg,
    })
    vim.api.nvim_set_hl(0, "ConfigTabInactive", {
        fg = inactive_fg,
        bg = inactive_bg,
    })
end

local function tab_count()
    return vim.fn.tabpagenr("$")
end

local function tab_windows(tabnr)
    local tabpage = vim.api.nvim_list_tabpages()[tabnr]

    if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
        return {}
    end

    return vim.api.nvim_tabpage_list_wins(tabpage)
end

local function tab_buffer_name(tabnr)
    for _, win in ipairs(tab_windows(tabnr)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if filetype ~= "NvimTree" and filetype ~= "alpha" then
                local name = vim.api.nvim_buf_get_name(buf)

                if name ~= "" then
                    return vim.fn.fnamemodify(name, ":t")
                end

                if vim.bo[buf].buftype == "terminal" then
                    return "terminal"
                end
            end
        end
    end

    return "[No Name]"
end

local function tab_label(tabnr)
    return string.format(
        "󰓩 %02d %s",
        tabnr - 1,
        tab_buffer_name(tabnr)
    )
end

local function is_empty_unnamed_buffer(buf)
    return vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_get_name(buf) == ""
        and vim.bo[buf].buftype == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function M.tabline()
    local parts = {}
    local current = vim.fn.tabpagenr()

    for tabnr = 1, tab_count() do
        local highlight = tabnr == current
                and "%#ConfigTabActive#"
            or "%#ConfigTabInactive#"

        table.insert(parts, highlight .. "%" .. tabnr .. "T " .. tab_label(tabnr) .. " ")
        table.insert(parts, "%#ConfigTabFill# ")
    end

    table.insert(parts, "%#ConfigTabFill#%T")

    return table.concat(parts)
end

function M.setup()
    apply_highlights()
    vim.o.showtabline = 1
    vim.o.tabline = "%!v:lua.require('config.tabs').tabline()"

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = apply_highlights,
    })
end

function M.new()
    vim.cmd("tabnew")
    local empty_buf = vim.api.nvim_get_current_buf()

    if is_empty_unnamed_buffer(empty_buf) then
        vim.bo[empty_buf].buflisted = false
    end

    local opened = pcall(vim.cmd, "DashboardHome")

    if
        opened
        and is_empty_unnamed_buffer(empty_buf)
        and empty_buf ~= vim.api.nvim_get_current_buf()
    then
        pcall(vim.api.nvim_buf_delete, empty_buf, {
            force = true,
        })
    end
end

function M.close()
    vim.cmd("tabclose")
end

function M.previous()
    vim.cmd("tabprevious")
end

function M.next()
    vim.cmd("tabnext")
end

function M.pick()
    local ok, telescope = pcall(function()
        return {
            actions = require("telescope.actions"),
            action_state = require("telescope.actions.state"),
            conf = require("telescope.config").values,
            finders = require("telescope.finders"),
            pickers = require("telescope.pickers"),
        }
    end)

    if not ok then
        vim.cmd("tabs")
        return
    end

    local entries = {}
    local current = vim.fn.tabpagenr()

    for tabnr = 1, tab_count() do
        table.insert(entries, {
            tabnr = tabnr,
            label = (tabnr == current and "* " or "  ") .. tab_label(tabnr),
        })
    end

    telescope.pickers
        .new({}, {
            initial_mode = "normal",
            default_selection_index = current,
            prompt_title = "Tabs",
            finder = telescope.finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.label,
                        ordinal = entry.label,
                    }
                end,
            }),
            sorter = telescope.conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                telescope.actions.select_default:replace(function()
                    local selected = telescope.action_state.get_selected_entry()

                    telescope.actions.close(prompt_bufnr)

                    if selected and selected.value then
                        vim.cmd("tabnext " .. selected.value.tabnr)
                    end
                end)

                map("n", "<Esc>", function()
                    telescope.actions.close(prompt_bufnr)
                end)

                return true
            end,
        })
        :find()
end

return M
