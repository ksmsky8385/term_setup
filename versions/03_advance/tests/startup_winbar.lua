-- nvim --noplugin --headless -u tests/startup_winbar.lua -i NONE
vim.opt.rtp:prepend(vim.fn.getcwd())
local original = vim.cmd
local early = 0
vim.cmd = setmetatable({}, {
    __index = original,
    __call = function(_, command)
        if type(command) == 'string' and command:find('redrawstatus', 1, true) and vim.v.vim_did_enter == 0 then
            early = early + 1
        end
        return original(command)
    end,
})
require('config.winbar').setup()
vim.cmd = original
assert(early == 0, 'winbar rendered the initial empty buffer before dashboard startup')
print('PASS: no forced winbar redraw before VimEnter')

vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    nested = true,
    callback = function()
        local redraws = 0
        local ready = false
        vim.cmd = setmetatable({}, {
            __index = original,
            __call = function(_, command)
                if type(command) == 'string' and command:find('redrawstatus', 1, true) then
                    assert(ready, 'winbar flushed an unfinished dashboard during VimEnter')
                    redraws = redraws + 1
                end
                return original(command)
            end,
        })
        -- Match the buffer and FileType transitions of dashboard startup.
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.bo[buf].filetype = 'alpha'
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Dashboard ready' })
        require('config.winbar').refresh()
        ready = true
        vim.schedule(function()
            assert(redraws == 1, 'startup redraws should be coalesced into one flush')
            assert(vim.wo.winbar == '', 'dashboard should not show an editor winbar')
            vim.cmd = original
            print('PASS: dashboard finishes before the single winbar redraw')
            vim.cmd('qa!')
        end)
    end,
})
