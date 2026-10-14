-- nvim --noplugin --headless -u tests/startup_winbar.lua -i NONE +qa!
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
