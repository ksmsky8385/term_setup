vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.shell = '/bin/sh'
require('config.toggle_state').write('editor_winbar', true)
local bar = require('config.winbar')
bar.setup()
require('config.keymaps')
require('config.terminal').setup()
local source = vim.api.nvim_get_current_win()
for _, kind in ipairs({'file', 'terminal'}) do
    vim.api.nvim_set_current_win(source)
    if kind == 'file' then
        vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. '.txt')
        bar.track(source)
    else
        require('config.terminal').create_buffer_terminal()
    end
    local original = vim.api.nvim_win_get_buf(source)
    local history = bar.items(source)
    for _, key in ipairs({'<leader>ts', '<leader>tv'}) do
        vim.api.nvim_set_current_win(source)
        vim.fn.maparg(key, 'n', false, true).callback()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        vim.wait(50, function() return false end)
        assert(win ~= source and vim.bo[buf].buftype == 'terminal')
        assert(vim.fn.jobwait({vim.b[buf].terminal_job_id}, 0)[1] == -1, 'terminal did not start')
        assert(vim.deep_equal(bar.items(win), {buf}), key .. ' inherited source history')
        assert(vim.deep_equal(bar.items(source), history), 'source history changed')
        assert(vim.api.nvim_win_get_buf(source) == original, 'source buffer changed')
        assert(bar.close_entry(win, buf, true))
        assert(not vim.api.nvim_win_is_valid(win), 'empty terminal split did not close')
        assert(vim.api.nvim_buf_is_valid(original), 'source buffer was deleted')
    end
end
print('PASS: ts/tv start with only their terminal, preserve source histories and close empty splits')
vim.cmd('qa!')
