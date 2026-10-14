local M = {}
local histories = {}
local offsets = {}
local active_buffers = {}
local restoring = false
local restored_scratch = {}
local restored_terminals = {}
local expression = "%!v:lua.require('config.winbar').render()"
local label
local drag
local hitboxes = {}
local reveal = {}
local scrollable = {}
local layout_signatures = {}
local owners = {}
local icon_highlights = {}

local function empty_editor_buffer()
    local buf = vim.api.nvim_create_buf(false, false)
    vim.bo[buf].swapfile = false
    return buf
end

local function terminal(buf)
    return vim.bo[buf].buftype == "terminal" or vim.b[buf].pending_terminal_restore ~= nil
end

function M.apply_highlights()
    icon_highlights = {}
    local function color(group, key, fallback)
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        return hl[key] or fallback
    end
    local normal_bg = vim.api.nvim_get_hl(0, {name = "Normal", link = false}).bg
    local bg = color("Normal", "bg", vim.o.background == "light" and 0xffffff or 0x1e1e1e)
    local fg = color("Normal", "fg", vim.o.background == "light" and 0x202020 or 0xd4d4d4)
    -- A terminal draws underlines inside the character cell, so they cut
    -- through the selected tab. Separate the bar from the editor by background.
    local bar_bg, item_bg = 0, 0
    for _, shift in ipairs({ 16, 8, 0 }) do
        local base = math.floor(bg / 2 ^ shift) % 256
        local foreground = math.floor(fg / 2 ^ shift) % 256
        bar_bg = bar_bg + math.floor(base * 0.88 + foreground * 0.12) * 2 ^ shift
        item_bg = item_bg + math.floor(base * 0.72 + foreground * 0.28) * 2 ^ shift
    end
    vim.api.nvim_set_hl(0, "ConfigWinbarFill", { fg = fg, bg = bar_bg, nocombine = true })
    vim.api.nvim_set_hl(0, "ConfigWinbarInactive", {
        fg = fg, bg = item_bg, bold = false, nocombine = true,
    })
    vim.api.nvim_set_hl(0, "ConfigWinbarActive", { fg = fg, bg = normal_bg, bold = true, nocombine = true })
    for _, kind in ipairs({'Active', 'Inactive'}) do
        local background = item_bg
        if kind == 'Active' then background = normal_bg end
        vim.api.nvim_set_hl(0, 'ConfigWinbarAdded' .. kind, {fg = color('GitSignsAdd', 'fg', 0x73b169), bg = background, nocombine = true})
        vim.api.nvim_set_hl(0, 'ConfigWinbarRemoved' .. kind, {fg = color('GitSignsDelete', 'fg', 0xe06c75), bg = background, nocombine = true})
    end
end

local function regular(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
        and (terminal(buf) or vim.api.nvim_buf_get_name(buf) ~= '' or vim.bo[buf].modified
            or vim.api.nvim_buf_line_count(buf) > 1
            or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= '')
        and (vim.bo[buf].buftype == "" or terminal(buf))
        and not vim.bo[buf].filetype:match("^Agentic")
        and not vim.tbl_contains({ "alpha", "NvimTree", "notify", "FloatingSlot" }, vim.bo[buf].filetype)
end

local function editor(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    if require('config.floating.state').is_slot_window(win) and vim.bo[buf].filetype == 'FloatingSlot' then return true end
    return (vim.api.nvim_win_get_config(win).relative == ""
        or require('config.floating.state').is_slot_window(win)) and not vim.wo[win].previewwindow
        and (vim.bo[buf].buftype == "" or terminal(buf))
        and not vim.bo[buf].filetype:match("^Agentic")
        and not vim.tbl_contains({ "alpha", "NvimTree", "notify", "FloatingSlot" }, vim.bo[buf].filetype)
end

function M.items(win)
    local clean = {}
    for _, buf in ipairs(histories[win] or {}) do
        if regular(buf) then clean[#clean + 1] = buf end
    end
    histories[win] = clean
    if owners[win] then owners[win].winbar_items = clean end
    return vim.deepcopy(clean)
end

function M.bind(win, owner)
    owners[win] = owner
    histories[win] = owner.winbar_items or {}
    M.track(win)
    M.refresh()
end

function M.close_entry(win, buf, force)
    return M.close(win, buf, force, function()
        if #M.items(win) > 0 then return end
        if require('config.floating.state').is_slot_window(win) then
            vim.api.nvim_set_current_win(win)
            require('config.floating').close_current(true, true)
        elseif M.on_empty then
            M.on_empty(win)
        end
    end)
end

function M.clear_window(win)
    histories[win], offsets[win], active_buffers[win] = nil, nil, nil
    reveal[win], scrollable[win], layout_signatures[win] = nil, nil, nil
    M.refresh()
end

function M.has_reference(buf, except)
    if not require('config.editor_settings').get('winbar') then return false end
    for win in pairs(histories) do
        if win ~= except and vim.api.nvim_win_is_valid(win)
            and vim.tbl_contains(M.items(win), buf) then return true end
    end
    local floating = require('config.floating.state')
    for _, item in pairs(floating.slots) do
        for _, owner in pairs(item.panes or {A = item}) do
            if owner ~= owners[except] and vim.tbl_contains(owner.winbar_items or {}, buf) then return true end
        end
    end
    return false
end

function M.refresh()
    for win, owner in pairs(owners) do
        if histories[win] then owner.winbar_items = histories[win] end
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local show = editor(win) and require('config.editor_settings').get('winbar')
        if show then
            vim.wo[win].winbar = expression
        elseif vim.wo[win].winbar == expression then
            vim.wo[win].winbar = ''
        end
    end
    local floating_window = package.loaded['config.floating.window']
    if floating_window then
        for slot in pairs(require('config.floating.state').slots) do floating_window.update_title(slot) end
    end
    if vim.v.vim_did_enter == 1 then vim.cmd('redrawstatus!') end
end

function M.track(win)
    if restoring or not editor(win) then return end
    local buf = vim.api.nvim_win_get_buf(win)
    if regular(buf) then
        local items = M.items(win)
        if not vim.tbl_contains(items, buf) then items[#items + 1] = buf end
        histories[win] = items
        local signature = tostring(buf) .. ':' .. vim.bo[buf].buftype .. ':' .. vim.api.nvim_buf_get_name(buf)
        if active_buffers[win] ~= signature then
            reveal[win] = true
            active_buffers[win] = signature
        end
    end
end

function M.cycle(direction)
    if not require('config.editor_settings').get('winbar') then return false end
    local win = vim.api.nvim_get_current_win()
    if not editor(win) then return false end
    local items = M.items(win)
    local index = vim.fn.index(items, vim.api.nvim_get_current_buf()) + 1
    if index == 0 or #items < 2 then return false end
    M.select(win, items[(index - 1 + direction) % #items + 1])
    return true
end

function M.move_current(direction)
    if not require('config.editor_settings').get('winbar') then return false end
    local win = vim.api.nvim_get_current_win()
    if not editor(win) then return false end
    local items = M.items(win)
    local index = vim.fn.index(items, vim.api.nvim_get_current_buf()) + 1
    local target = index + direction
    if index == 0 or target < 1 or target > #items then return false end
    items[index], items[target] = items[target], items[index]
    histories[win] = items
    active_buffers[win] = nil
    M.track(win)
    M.refresh()
    return true
end

function M.select(win, buf)
    if not vim.api.nvim_win_is_valid(win) or not vim.tbl_contains(M.items(win), buf) then return end
    vim.api.nvim_set_current_win(win)
    local ok, err = pcall(vim.api.nvim_win_set_buf, win, buf)
    if ok and vim.b[buf].pending_terminal_restore then
        require('config.terminal').start_pending(win)
    end
    if not ok then vim.notify(tostring(err), vim.log.levels.WARN) end
end

function M.close(win, buf, force, on_closed)
    if not vim.api.nvim_win_is_valid(win) then return false end
    local items = M.items(win)
    local index = vim.fn.index(items, buf) + 1
    if index == 0 then return false end
    local shared = M.has_reference(buf, win)
    -- A buffer visible outside the tracked editor windows must also survive.
    for _, other in ipairs(vim.api.nvim_list_wins()) do
        if other ~= win and vim.api.nvim_win_get_buf(other) == buf then shared = true end
    end
    if not shared and terminal(buf) and not force then
        local job = vim.b[buf].terminal_job_id
        if job and vim.fn.jobwait({job}, 0)[1] == -1 then
            vim.ui.select({'Cancel', 'Terminate terminal'}, {prompt = 'Close the last reference to this running terminal?'}, function(choice)
                if choice == 'Terminate terminal' then M.close(win, buf, true, on_closed) end
            end)
            return false
        end
    end
    if not shared and not terminal(buf) and vim.bo[buf].modified and not force then
        vim.notify('Unsaved changes: save the buffer before closing its last window entry.', vim.log.levels.WARN)
        return false
    end
    local old = vim.deepcopy(items)
    table.remove(items, index)
    histories[win] = items
    if vim.api.nvim_win_get_buf(win) == buf then
        local replacement = items[math.min(index, #items)]
            or empty_editor_buffer()
        local ok, err = pcall(vim.api.nvim_win_set_buf, win, replacement)
        if not ok then
            histories[win] = old
            vim.notify(tostring(err), vim.log.levels.WARN)
            return false
        end
        if vim.b[replacement].pending_terminal_restore then
            require('config.terminal').start_pending(win)
        end
    end
    if not shared then
        local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = force == true })
        if not ok then
            histories[win] = old
            vim.notify(tostring(err), vim.log.levels.WARN)
            M.refresh()
            return false
        end
    end
    offsets[win] = math.min(offsets[win] or 1, math.max(1, #items))
    M.refresh()
    if on_closed then on_closed() end
    return true
end

local function region(id, callback, text)
    return '%' .. id .. '@v:lua.' .. callback .. '@' .. text:gsub('%%', '%%%%') .. '%X'
end

label = function(buf, limit)
    local path = vim.api.nvim_buf_get_name(buf)
    local name = terminal(buf) and ('Terminal ' .. buf)
        or (path == '' and '[No Name]' or vim.fn.fnamemodify(path, ':t'))
    if vim.fn.strdisplaywidth(name) > limit then
        while vim.fn.strdisplaywidth(name) > math.max(0, limit - 3) do
            name = vim.fn.strcharpart(name, 0, vim.fn.strchars(name) - 1)
        end
        name = name .. '...'
    end
    local icon, icon_group = '', 'DiagnosticInfo'
    if not terminal(buf) then
        local ok, icons = pcall(require, 'nvim-web-devicons')
        if ok then
            icon, icon_group = icons.get_icon(vim.fn.fnamemodify(path, ':t'), vim.fn.fnamemodify(path, ':e'), {default = true})
        else
            icon, icon_group = '', 'DiagnosticInfo'
        end
    end
    local added, removed = require('config.buffer_changes').count(buf)
    local changes = {}
    if added > 0 then changes[#changes + 1] = '+' .. added end
    if removed > 0 then changes[#changes + 1] = '-' .. removed end
    local status = #changes > 0 and (' ' .. table.concat(changes, ' '))
        or (vim.bo[buf].modified and not terminal(buf) and ' ●' or '')
    return icon .. ' ' .. name .. status, icon, icon_group, status
end

local function icon_highlight(group, kind)
    local base = vim.api.nvim_get_hl(0, {name = 'ConfigWinbar' .. kind, link = false})
    local source = vim.api.nvim_get_hl(0, {name = group or 'DiagnosticInfo', link = false})
    local name = 'ConfigWinbarIcon' .. kind .. (group or 'Default')
    local spec = {fg = source.fg or base.fg, bg = base.bg, bold = base.bold, nocombine = true}
    if not vim.deep_equal(icon_highlights[name], spec) then
        vim.api.nvim_set_hl(0, name, spec)
        icon_highlights[name] = spec
    end
    return name
end

function M.render()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    if not editor(win) then return '' end
    local items = M.items(win)
    local width = vim.api.nvim_win_get_width(win)
    hitboxes[win] = {}
    local prefix = ''
    local floating = require('config.floating.state')
    local slot = floating.window_slot_id(win)
    if slot then
        prefix = ' [' .. (tostring(slot) == '`' and '~' or tostring(slot)) .. ']'
        local item = floating.slots[tostring(slot)]
        if item and item.panes and vim.tbl_count(item.panes) > 1 then
            prefix = prefix .. '[' .. floating.window_pane_id(win) .. ']'
        end
        prefix = prefix .. ' '
    end
    local prefix_width = vim.fn.strdisplaywidth(prefix)
    if #items == 0 then return '%#ConfigWinbarFill#' .. prefix .. ' ' end
    local available = math.max(1, width - 6 - prefix_width)
    local limit = math.max(3, math.min(26, available - 8))
    local function size_at(index)
        return vim.fn.strdisplaywidth((label(items[index], limit))) + 6
    end
    if require('config.editor_settings').get('winbar_compress') then
        while limit > 3 do
            local total = 0
            for index = 1, #items do total = total + size_at(index) end
            if total <= available then break end
            limit = limit - 1
        end
    end
    local function last_visible(first)
        local used, last = 0, first
        for index = first, #items do
            local size = size_at(index)
            if used + size > available and index > first then break end
            used, last = used + size, index
        end
        return last
    end
    local signature = tostring(width) .. ':' .. prefix_width .. ':' .. limit
    for index, buf in ipairs(items) do signature = signature .. ':' .. buf .. '/' .. size_at(index) end
    if layout_signatures[win] ~= signature then
        reveal[win] = true
        layout_signatures[win] = signature
    end
    local first = math.min(offsets[win] or 1, #items)
    if last_visible(1) == #items then first = 1 end
    if reveal[win] then
        local current = vim.fn.index(items, vim.api.nvim_win_get_buf(win)) + 1
        if current > 0 then
            if current < first then first = current end
            while last_visible(first) < current do first = first + 1 end
        end
        reveal[win] = nil
    end
    offsets[win] = first
    local last = last_visible(first)
    scrollable[win] = {first > 1, last < #items}
    local parts = { '%#ConfigWinbarFill#', prefix, first > 1 and region(1, 'ConfigWinbarScroll', ' ‹ ') or '   ' }
    local used = 0
    for index = first, #items do
        local buf = items[index]
        local caption, icon, icon_group, status = label(buf, limit)
        local text = ' ' .. caption .. ' '
        local size = vim.fn.strdisplaywidth(text) + 4
        if used + size > available and index > first then break end
        hitboxes[win][#hitboxes[win] + 1] = { buf = buf, first = prefix_width + used + 4 + (vim.api.nvim_win_get_config(win).relative == '' and 0 or 1), last = prefix_width + used + size + 3 + (vim.api.nvim_win_get_config(win).relative == '' and 0 or 1) }
        parts[#parts + 1] = buf == vim.api.nvim_win_get_buf(win) and '%#ConfigWinbarActive#' or '%#ConfigWinbarInactive#'
        local kind = buf == vim.api.nvim_win_get_buf(win) and 'Active' or 'Inactive'
        local status_text = status:gsub('(%+%d+)', '%%#ConfigWinbarAdded' .. kind .. '#%1%%#ConfigWinbar' .. kind .. '#')
            :gsub('(%-%d+)', '%%#ConfigWinbarRemoved' .. kind .. '#%1%%#ConfigWinbar' .. kind .. '#')
        local entry = '%' .. buf .. '@v:lua.ConfigWinbarSelect@ '
            .. '%#' .. icon_highlight(icon_group, kind) .. '#' .. icon
            .. '%#ConfigWinbar' .. kind .. '#'
            .. caption:sub(#icon + 1, #caption - #status):gsub('%%', '%%%%')
            .. status_text .. ' %X'
        parts[#parts + 1] = entry
        parts[#parts + 1] = region(buf, 'ConfigWinbarClose', ' × ')
        parts[#parts + 1] = '%#ConfigWinbarFill# '
        used = used + size
    end
    parts[#parts + 1] = '%#ConfigWinbarFill#%=' .. (last < #items and region(2, 'ConfigWinbarScroll', ' › ') or '   ')
    return table.concat(parts)
end

-- Called by buffer-local mouse handlers before interpreting a body click.
function M.forward_mouse(key)
    local mouse = vim.fn.getmousepos()
    if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid)
        or vim.wo[mouse.winid].winbar ~= expression or mouse.winrow ~= (vim.api.nvim_win_get_config(mouse.winid).relative == '' and 1 or 2)
        or mouse.line ~= 0 then return false end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'ni', false)
    return true
end

-- Move ownership without deleting the buffer (including a running terminal).
function M.drop(source, buf, target, before)
    if not require('config.editor_settings').get('winbar') or not editor(source)
        or not editor(target) or not vim.tbl_contains(M.items(source), buf) then return false end
    if source == target and before == buf then return true end
    local source_items, target_items = M.items(source), M.items(target)
    target_items = vim.tbl_filter(function(item) return item ~= buf end, target_items)
    local index = before and vim.fn.index(target_items, before) + 1 or 0
    table.insert(target_items, index > 0 and index or #target_items + 1, buf)
    if source ~= target then
        local old_target = vim.api.nvim_win_get_buf(target)
        local remaining = vim.tbl_filter(function(item) return item ~= buf end, source_items)
        local previous_restoring = restoring
        restoring = true
        local ok, err = pcall(function()
            vim.api.nvim_win_set_buf(target, buf)
            if vim.api.nvim_win_get_buf(source) == buf then
                vim.api.nvim_win_set_buf(source, remaining[1] or empty_editor_buffer())
            end
        end)
        restoring = previous_restoring
        if not ok then
            pcall(vim.api.nvim_win_set_buf, target, old_target)
            vim.notify(tostring(err), vim.log.levels.WARN)
            return false
        end
        histories[source] = remaining
        active_buffers[source] = nil
        M.track(source)
    end
    histories[target] = target_items
    active_buffers[target] = nil
    M.track(target)
    vim.api.nvim_set_current_win(target)
    if vim.b[buf].pending_terminal_restore then require('config.terminal').start_pending(target) end
    M.refresh()
    return true
end

function M.start_file_drag(path)
    local mouse = vim.fn.getmousepos()
    drag = nil
    if type(path) == 'string' and vim.fn.filereadable(path) == 1 then
        drag = {path = path, row = mouse.screenrow, col = mouse.screencol}
    end
end

local function release_drag(mouse, captured)
    if not captured.moved or not editor(mouse.winid) then return end
    if mouse.line == 0 and not (mouse.winrow == (vim.api.nvim_win_get_config(mouse.winid).relative == '' and 1 or 2) and vim.wo[mouse.winid].winbar == expression) then return end
    if captured.path then
        local buf = require('config.swap').load_buffer(captured.path, {win = mouse.winid})
        if buf then
            vim.api.nvim_set_current_win(mouse.winid)
            local ok, err = pcall(vim.api.nvim_win_set_buf, mouse.winid, buf)
            if not ok then vim.notify(tostring(err), vim.log.levels.WARN) end
        end
        return
    end
    local before
    if mouse.winrow == (vim.api.nvim_win_get_config(mouse.winid).relative == '' and 1 or 2) and mouse.line == 0 then
        for _, box in ipairs(hitboxes[mouse.winid] or {}) do
            if mouse.wincol <= (box.first + box.last) / 2 then
                before = box.buf
                break
            end
        end
    end
    M.drop(captured.win, captured.buf, mouse.winid, before)
end

function M.handle_drag(key)
    if not drag then
        -- A tree row is a file item, not editable text. Do not fall through to
        -- native character/word/line selection when there is no draggable file.
        return key
    end
    local mouse = vim.fn.getmousepos()
    if key:find('Drag', 1, true) then
        drag.moved = drag.moved or mouse.screenrow ~= drag.row or mouse.screencol ~= drag.col
    else
        local captured = drag
        drag = nil
        vim.schedule(function() release_drag(mouse, captured) end)
    end
    return '<Ignore>'
end

function M.snapshot_items(items)
    local result = {}
    for _, buf in ipairs(items) do
        if not regular(buf) then goto continue end
        local path = vim.api.nvim_buf_get_name(buf)
        if terminal(buf) then
            local pending = vim.b[buf].pending_terminal_restore
            result[#result + 1] = {
                terminal = tostring(buf),
                cwd = (pending and pending.cwd) or require('config.terminal').actual_cwd(buf) or vim.fn.getcwd(),
            }
        elseif path ~= '' then
            result[#result + 1] = path
        else
            result[#result + 1] = {
                scratch = tostring(buf),
                lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
                filetype = vim.bo[buf].filetype,
                modified = vim.bo[buf].modified,
            }
        end
        ::continue::
    end
    return result
end

function M.snapshot(win)
    return M.snapshot_items(M.items(win))
end

function M.restore_terminal(key, descriptor)
    local buf = key and restored_terminals[key]
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        buf = require('config.terminal').restore_buffer(descriptor)
        if key then restored_terminals[key] = buf end
    end
    return buf
end

function M.restore_items(paths, active)
    local items = {}
    local selected
    for index, path in ipairs(type(paths) == 'table' and paths or {}) do
        if type(path) == 'string' and vim.fn.filereadable(path) == 1 then
            local buf = vim.fn.bufadd(path)
            vim.bo[buf].buflisted = true
            if index == active then selected = buf end
            if not vim.tbl_contains(items, buf) then
                table.insert(items, buf)
            end
        elseif type(path) == 'table' and type(path.terminal) == 'string' then
            local buf = M.restore_terminal(path.terminal, path)
            table.insert(items, buf)
            if index == active then selected = buf end
        elseif type(path) == 'table' and type(path.scratch) == 'string' and type(path.lines) == 'table' then
            local buf = restored_scratch[path.scratch]
            if not buf or not vim.api.nvim_buf_is_valid(buf) then
                buf = vim.api.nvim_create_buf(true, false)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, path.lines)
                vim.bo[buf].filetype = path.filetype or ''
                vim.bo[buf].modified = path.modified == true
                restored_scratch[path.scratch] = buf
            end
            if index == active then selected = buf end
            table.insert(items, buf)
        end
    end
    return items, selected
end

function M.restore_window(win, paths, active)
    local items, selected = M.restore_items(paths, active)
    histories[win], offsets[win] = items, 1
    local current = vim.api.nvim_win_get_buf(win)
    if selected then
        vim.api.nvim_win_set_buf(win, selected)
        current = selected
        if vim.b[selected].pending_terminal_restore then require('config.terminal').start_pending(win) end
    end
    if regular(current) and not vim.tbl_contains(histories[win], current) then
        table.insert(histories[win], current)
    end
end

function M.begin_restore()
    restoring = true
    histories = {}
    owners = {}
    offsets = {}
    active_buffers = {}
    restored_scratch = {}
    restored_terminals = {}
end

function M.end_restore()
    restoring = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do M.track(win) end
    M.refresh()
end

function M.setup()
    vim.o.hidden = true
    M.apply_highlights()
    require('config.buffer_changes').setup()
    for _, prefix in ipairs({'', '2-', '3-', '4-'}) do
        for _, event in ipairs({'LeftDrag', 'LeftRelease'}) do
            local key = '<' .. prefix .. event .. '>'
            vim.keymap.set({'n', 'i', 't', 'x'}, key, function()
                return M.handle_drag(key)
            end, {expr = true, silent = true, desc = 'Drag winbar buffer or preserve native mouse action'})
        end
    end
    _G.ConfigWinbarSelect = function(buf, _, button)
        if button == 'l' then
            local mouse = vim.fn.getmousepos()
            drag = {win = mouse.winid, buf = buf, row = mouse.screenrow, col = mouse.screencol}
            M.select(mouse.winid, buf)
        end
    end
    _G.ConfigWinbarClose = function(buf, clicks, button)
        if button == 'l' and clicks == 1 then
            local win = vim.fn.getmousepos().winid
            M.close_entry(win, buf, false)
        end
    end
    _G.ConfigWinbarScroll = function(direction, _, button)
        if button ~= 'l' then return end
        local win = vim.fn.getmousepos().winid
        if not scrollable[win] or not scrollable[win][direction] then return end
        local count = #M.items(win)
        offsets[win] = math.max(1, math.min(count, (offsets[win] or 1) + (direction == 1 and -1 or 1)))
        if vim.v.vim_did_enter == 1 then vim.cmd('redrawstatus!') end
    end
    local group = vim.api.nvim_create_augroup('ConfigWindowBuffers', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = function() M.apply_highlights(); M.refresh() end })
    vim.api.nvim_create_autocmd({ 'TermOpen', 'TermEnter', 'TermLeave', 'BufEnter', 'BufWinEnter', 'WinEnter', 'BufFilePost', 'FileType' }, {
        group = group,
        callback = function()
            M.track(vim.api.nvim_get_current_win())
            M.refresh()
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'BufWritePost', 'WinResized', 'TextChanged', 'TextChangedI' }, {
        group = group, callback = function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                reveal[win] = true
                M.track(win)
            end
            M.refresh()
        end,
    })
    vim.api.nvim_create_autocmd('TermOpen', {group = group, callback = function(args)
        vim.schedule(function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == args.buf then reveal[win] = true; M.track(win) end
            end
            M.refresh()
        end)
    end})
    vim.api.nvim_create_autocmd('WinClosed', {
        group = group,
        callback = function(args)
            local win = tonumber(args.match)
            if owners[win] then owners[win].winbar_items = histories[win] or {}; owners[win] = nil end
            histories[win], offsets[win] = nil, nil
            active_buffers[win] = nil
            reveal[win], scrollable[win], layout_signatures[win] = nil, nil, nil
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
        group = group,
        callback = function(args)
            for win, items in pairs(histories) do
                histories[win] = vim.tbl_filter(function(buf) return buf ~= args.buf end, items)
            end
            vim.schedule(M.refresh)
        end,
    })
    for _, win in ipairs(vim.api.nvim_list_wins()) do M.track(win) end
    M.refresh()
end

return M
