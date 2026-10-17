vim.opt.rtp:prepend(vim.fn.getcwd())
for _, plugin in ipairs({'nvim-tree.lua', 'nvim-web-devicons', 'alpha-nvim'}) do
    vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/' .. plugin))
end
require('config.toggle_state').write('editor_winbar', true)
local bar = require('config.winbar')
bar.setup()
require('config.keymaps')
require('plugins.dashboard').config()
require('plugins.nvim-tree').config()
local api = require('nvim-tree.api')
local source = vim.api.nvim_get_current_win()
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local a, b = dir .. '/source.txt', dir .. '/target.txt'
vim.fn.writefile({'source'}, a)
vim.fn.writefile({'target'}, b)
vim.cmd.edit(a)
local original = vim.api.nvim_get_current_buf()
vim.cmd.cd(dir)
vim.g.current_workspace_root = dir
api.tree.open({path = dir})
local tree = api.tree.winid()
local picker = require('config.window_picker')
picker.pick_window = function() return source end
for _, case in ipairs({{'s', b}, {'v', b}, {'s', a}, {'v', a}}) do
    local key, path = unpack(case)
    vim.api.nvim_set_current_win(tree)
    for row, line in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(tree), 0, -1, false)) do
        if line:find(vim.fn.fnamemodify(path, ':t'), 1, true) then vim.api.nvim_win_set_cursor(tree, {row, 0}) end
    end
    local map = vim.fn.maparg(key, 'n', false, true)
    map.callback()
    local split = vim.api.nvim_get_current_win()
    local opened = vim.api.nvim_win_get_buf(split)
    assert(split ~= source and vim.api.nvim_buf_get_name(opened) == path)
    assert(vim.deep_equal(bar.items(split), {opened}), 'tree split inherited source history')
    assert(vim.deep_equal(bar.items(source), {original}), 'source history changed')
    assert(bar.close_entry(split, opened, false))
    assert(not vim.api.nvim_win_is_valid(split), 'empty split must close')
end
-- A tree preview / minimap / other float must not count as another tiled editor.
local preview_buf = vim.api.nvim_create_buf(false, true)
local preview = vim.api.nvim_open_win(preview_buf, false, {
    relative = 'editor', row = 1, col = 1, width = 12, height = 3, style = 'minimal',
})
for _, action in ipairs({'leader', 'cross'}) do
    vim.api.nvim_set_current_win(source)
    vim.cmd.edit(a)
    local buf = vim.api.nvim_get_current_buf()
    if action == 'leader' then
        vim.fn.maparg('<leader>q', 'n', false, true).callback()
    else
        -- Clicking an inactive window's cross must render Alpha in that window.
        vim.api.nvim_set_current_win(tree)
        assert(bar.close_entry(source, buf, false))
    end
    assert(vim.api.nvim_win_is_valid(source), 'last editor closed while a float remained')
    assert(vim.bo[vim.api.nvim_win_get_buf(source)].filetype == 'alpha', 'missing dashboard')
    assert(vim.bo[vim.api.nvim_win_get_buf(tree)].filetype == 'NvimTree', 'tree replaced')
    assert(vim.api.nvim_win_is_valid(preview))
end
print('PASS: tree s/v histories, last editor dashboard with float, inactive cross target')
vim.cmd('qa!')
