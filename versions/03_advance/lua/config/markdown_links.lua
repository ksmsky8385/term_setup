local M = {}

local function disable_terminal_links()
    -- OSC 8 URLs are handled by the terminal before Neovim sees Ctrl+click.
    -- Keep the installed highlighting/conceal rules, but route clicks through
    -- our buffer mapping instead of publishing Markdown destinations to it.
    if M.terminal_links_disabled then return end
    local files = vim.treesitter.query.get_files("markdown_inline", "highlights")
    if #files == 0 then return end
    local parts = {}
    for _, file in ipairs(files) do
        local source = table.concat(vim.fn.readfile(file), "\n")
        source = source:gsub('%(#set!%s+@[%w_%.%-]+%s+url%s+[^%)]+%)', '')
        parts[#parts + 1] = source
    end
    local ok = pcall(vim.treesitter.query.set, "markdown_inline", "highlights", table.concat(parts, "\n"))
    M.terminal_links_disabled = ok
end

local function decode(value)
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function jump(fragment)
    local counts = {}
    for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local found = false
        for _, attribute in ipairs({ "id", "name" }) do
            for value in line:gmatch(attribute .. "%s*=%s*['\"](.-)['\"]") do
                found = found or value == fragment
            end
        end
        local heading = line:match("^%s*#+%s+(.+)")
        if heading then
            local slug = vim.fn.tolower((heading:gsub("%s+#+%s*$", "")))
                :gsub("<[^>]+>", ""):gsub("[%p]", function(c)
                    return (c == "-" or c == "_") and c or ""
                end):gsub("%s", "-")
            local count = counts[slug] or 0
            counts[slug] = count + 1
            found = found or fragment == (slug .. (count > 0 and ("-" .. count) or ""))
        end
        if found then
            vim.cmd("normal! m'")
            vim.api.nvim_win_set_cursor(0, { row, 0 })
            vim.cmd("normal! zvzz")
            return
        end
    end
    vim.notify("Markdown anchor not found: #" .. fragment, vim.log.levels.WARN)
end

function M.open(target)
    target = vim.trim(target):gsub("^<(.*)>$", "%1")
    if target == "" then return end
    if target:match("^[%a][%w+.-]*:") and not target:match("^file://") then
        local _, err = vim.ui.open(target)
        if err then vim.notify(err, vim.log.levels.ERROR) end
        return
    end
    local path, fragment = target:match("^(.-)#(.*)$")
    path = decode(path or target)
    if path ~= "" then
        local preview_source = vim.b.markdown_preview_source
        path = path:gsub("^file://localhost/", "/"):gsub("^file://", "")
        if path:sub(1, 1) ~= "/" then
            path = vim.fs.dirname(preview_source or vim.api.nvim_buf_get_name(0)) .. "/" .. path
        end
        path = vim.fs.normalize(path)
        if vim.fn.filereadable(path) ~= 1 then
            vim.notify("Markdown file not found: " .. path, vim.log.levels.WARN)
            return
        end
        local source_win = vim.api.nvim_get_current_win()
        local target_win = source_win
        if preview_source then
            local picker = require("config.window_picker")
            target_win = nil
            local exclude = { filetype = { "NvimTree", "notify" } }
            for _, win in ipairs(picker.selectable_windows(exclude)) do
                if vim.api.nvim_win_get_config(win).relative == ""
                    and picker.label_for_window(win, exclude) == "A" then
                    target_win = win
                    break
                end
            end
            if not target_win then
                vim.notify("Markdown link: A window not found", vim.log.levels.WARN)
                return
            end
        end
        -- :edit preserves modified-buffer protection and reuses existing buffers.
        -- Keep the preview buffer (and its Esc/Tab mappings) intact.
        local ok, err = pcall(vim.api.nvim_win_call, target_win, function()
            vim.cmd.edit(vim.fn.fnameescape(path))
        end)
        if not ok then
            vim.notify(err, vim.log.levels.WARN)
            return
        end
        vim.api.nvim_set_current_win(target_win)
        if preview_source and source_win ~= target_win and vim.api.nvim_win_is_valid(source_win) then
            vim.api.nvim_win_close(source_win, true)
        end
    end
    if fragment and fragment ~= "" then jump(decode(fragment)) end
end

function M.follow()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1
    -- Resolve the whole label, including when the destination is concealed.
    local offset = 1
    while true do
        local first, last, _, destination = line:find("(%b[])(%b())", offset)
        if not first then break end
        if col >= first and col <= last then
            destination = destination:sub(2, -2)
            M.open(destination:match("^%s*<(.-)>")
                or destination:gsub('%s+[\"\'].*$', ""))
            return
        end
        offset = last + 1
    end
    local urls = vim.ui._get_urls and vim.ui._get_urls() or { vim.fn.expand("<cfile>") }
    if urls[1] then M.open(urls[1]) end
end

function M.setup()
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("MarkdownLinks", { clear = true }),
        pattern = "markdown",
        callback = function(event)
            disable_terminal_links()
            vim.keymap.set("n", "gx", M.follow, { buffer = event.buf, desc = "Follow Markdown link" })
            vim.keymap.set("n", "<C-LeftMouse>", function()
                local mouse = vim.fn.getmousepos()
                if mouse.winid == 0 or mouse.line == 0 then return end
                vim.api.nvim_set_current_win(mouse.winid)
                if vim.bo.filetype ~= "markdown" then return end
                vim.api.nvim_win_set_cursor(0, { mouse.line, math.max(0, mouse.column - 1) })
                M.follow()
            end, { buffer = event.buf, desc = "Follow Markdown link under mouse" })
        end,
    })
end

return M
