local root = vim.fn.getcwd()
for _, case in ipairs({{false, false}, {true, false}, {false, true}, {true, true}}) do
    local dirty, terminal = unpack(case)
    local job = vim.fn.jobstart({'/usr/bin/nvim', '--embed', '--headless', '-u', 'NONE', '-i', 'NONE'}, {rpc = true})
    local function req(method, ...)
        local result = {pcall(vim.rpcrequest, job, method, ...)}
        if not result[1] then error(method .. ': ' .. tostring(result[2])) end
        return unpack(result, 2)
    end
    local function lua(code, args) return req('nvim_exec_lua', code, args or {}) end
    req('nvim_ui_attach', 120, 40, {rgb = true})
    lua([[
        local root, dirty, terminal = ...
        vim.opt.rtp:prepend(root)
        vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/alpha-nvim'))
        vim.o.mouse = 'a'
        require('config.keymaps')
        require('plugins.dashboard').config()
        if dirty then
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf, '/tmp/dashboard-unsaved.txt')
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'unsaved work'})
            _G.dirtybuf = buf
        end
        if terminal then
            vim.fn.termopen({'sh', '-c', 'sleep 60'})
            _G.termbuf = vim.api.nvim_get_current_buf()
        end
        vim.cmd('DashboardHome')
        _G.home = vim.api.nvim_get_current_win()
        vim.cmd('redraw!')
    ]], {root, dirty, terminal})
    local function click(row, col, modifier)
        req('nvim_input_mouse', 'left', 'press', modifier or '', 0, row, col)
        req('nvim_input_mouse', 'left', 'release', modifier or '', 0, row, col)
        vim.wait(50, function() return false end)
    end
    local function open_prompt()
        local pt = lua([[
            for row, line in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(home), 0, -1, false)) do
                local col = line:find('Quit Neovim', 1, true)
                if col then local p = vim.fn.screenpos(home, row, col); return {p.row-1, p.col-1} end
            end
            error('missing Quit Neovim button')
        ]])
        click(pt[1], pt[2], '2')
        assert(lua([[return vim.api.nvim_win_get_config(0).relative == 'editor'
            and vim.api.nvim_buf_get_lines(0,0,1,false)[1] == 'Quit Neovim?']]), 'release dismissed confirmation')
    end
    local function button(label)
        return lua([[
            for row, line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
                if line:find(...,1,true) then
                    local p=vim.fn.screenpos(0,row,2); return {p.row-1,p.col-1}
                end
            end
            error('missing button')
        ]], {label})
    end
    open_prompt()
    local contents = lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false), '\n')]])
    local summary = dirty and (terminal and 'Unsaved buffers and running terminals' or 'Unsaved buffers')
        or (terminal and 'Running terminals' or 'Close all Neovim windows?')
    assert(contents:find(summary, 1, true), 'incorrect blocker summary')
    if dirty then assert(contents:find('dashboard-unsaved.txt', 1, true), 'missing modified buffer name') end
    if terminal then
        local name = lua('return vim.api.nvim_buf_get_name(termbuf)')
        assert(contents:find(name, 1, true), 'missing terminal name')
    end
    local cancel = button('Cancel')
    click(cancel[1], cancel[2])
    assert(lua([[return vim.bo.filetype == 'alpha']]), 'cancel did not return to dashboard')
    if dirty then assert(lua('return vim.bo[dirtybuf].modified'), 'cancel lost unsaved work') end
    -- The leader-Esc mapping and dashboard mouse button share the dialog.
    lua([[vim.fn.maparg('<leader><Esc>', 'n', false, true).callback()]])
    assert(lua([[return vim.api.nvim_buf_get_lines(0,0,1,false)[1] == 'Quit Neovim?']]))
    req('nvim_input', 'c')
    vim.wait(30, function() return false end)
    assert(lua([[return vim.bo.filetype == 'alpha']]), 'keyboard cancel failed')
    lua([[vim.fn.maparg('<leader><Esc>', 'n', false, true).callback()]])
    req('nvim_input', '<Esc>')
    vim.wait(30, function() return false end)
    assert(lua([[return vim.bo.filetype == 'alpha']]), 'Escape cancel failed')
    open_prompt()
    if dirty or terminal then
        req('nvim_input', 'q')
        vim.wait(30, function() return false end)
        assert(lua([[return vim.api.nvim_buf_get_lines(0,0,1,false)[1] == 'Quit Neovim?']]), 'lowercase q forced quit')
        req('nvim_input', dirty and 'Q' or '<Tab><CR>')
    else
        local accept = button('Quit Neovim ]')
        pcall(click, accept[1], accept[2])
    end
    assert(vim.fn.jobwait({job}, 2000)[1] == 0, 'mouse confirmation did not quit Neovim')
end
print('PASS: blocker summaries/names, mouse quit/cancel, leader-Esc dialog, keyboard cancel/force quit/navigation')
vim.cmd('qa!')
