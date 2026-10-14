-- Run with an isolated XDG_STATE_HOME: nvim --headless -u NONE -i NONE -l tests/winbar.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local bar = require('config.winbar')
require('config.toggle_state').write('editor_winbar', true)
bar.setup()
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local function file(name)
    local path = dir .. '/' .. name
    vim.fn.writefile({'one', 'two'}, path)
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true
    return buf
end
local a, b, c = file('alpha.txt'), file('beta.txt'), file('한글%name.txt')
local left = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(left, a)
vim.api.nvim_win_set_buf(left, b)
assert(vim.deep_equal(bar.items(left), {a,b}))
vim.cmd('vsplit')
local right = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(right, a)
vim.api.nvim_win_set_buf(right, c)
assert(vim.deep_equal(bar.items(right), {b,a,c}), 'new split inherits only its visible buffer')
assert(bar.close(left, a))
assert(vim.api.nvim_buf_is_valid(a), 'hidden reference must preserve buffer')
assert(not vim.tbl_contains(bar.items(left), a))
assert(bar.close(right, a))
assert(not vim.api.nvim_buf_is_valid(a) or not vim.bo[a].buflisted, 'last close must delete buffer')
vim.api.nvim_buf_set_lines(c, 0, 1, false, {'changed'})
assert(bar.render():find('+1', 1, true) and bar.render():find('-1', 1, true), 'modified indicator missing')
assert(not bar.close(right, c), 'last modified reference must be protected')
vim.api.nvim_win_set_buf(left, c)
assert(bar.close(right, c), 'shared modified reference can close')
assert(vim.bo[c].modified)
assert(vim.tbl_contains(bar.items(left), c))
vim.bo[c].modified = false
local settings = require('config.editor_settings')
settings.cycle('winbar')
assert(vim.wo[left].winbar == '' and vim.wo[right].winbar == '')
assert(not bar.has_reference(c), 'disabled winbar must not protect hidden buffers')
assert(vim.tbl_contains(bar.items(left), c), 'hiding must retain history')
settings.cycle('winbar')
assert(vim.wo[left].winbar ~= '')
-- Auto-close must not destroy a hidden buffer still in a window history.
require('config.buffers.auto_close').setup()
if not require('config.buffers.auto_close').enabled() then require('config.buffers.auto_close').toggle() end
vim.api.nvim_set_current_win(left)
vim.api.nvim_win_set_buf(left, b)
vim.wait(30, function() return false end)
assert(vim.bo[c].buflisted)
-- Exercise the actual session layout serializer/restorer through JSON.
local layout = require('config.sessions.layout')
vim.cmd('tabnew')
local third = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(third, c)
vim.api.nvim_win_set_buf(third, b)
local before = layout.snapshot()
local encoded = vim.json.decode(vim.json.encode(before))
assert(layout.restore(encoded))
local after = layout.snapshot()
for i, tab in ipairs(before.tabs) do
    for leaf, descriptor in pairs(tab.windows) do
        assert(vim.deep_equal(descriptor.window_buffers, after.tabs[i].windows[leaf].window_buffers), 'session history mismatch')
    end
end
-- With the feature disabled, the existing current-buffer delete path ignores
-- other windows' hidden history references.
local d, e = file('delete-off.txt'), file('replacement.txt')
local one = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(one, d)
vim.cmd('vsplit')
local two = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(two, e)
vim.api.nvim_set_current_win(one)
settings.cycle('winbar')
assert(require('config.buffers.actions').delete_current(false))
assert(not vim.api.nvim_buf_is_valid(d) or not vim.bo[d].buflisted, 'disabled close must retain old delete behavior')
settings.cycle('winbar')
-- Old sessions without history are still accepted.
for _, tab in ipairs(encoded.tabs) do
    for _, descriptor in pairs(tab.windows) do descriptor.window_buffers = nil end
end
assert(layout.restore(encoded))
-- Missing history files must not create bogus buffers.
local win = vim.api.nvim_get_current_win()
bar.restore_window(win, {dir .. '/missing.txt'})
assert(#bar.items(win) <= 1)
local scratch = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, {'unsaved note'})
vim.api.nvim_win_set_buf(win, scratch)
vim.cmd('vsplit')
local scratch_snapshot = vim.json.decode(vim.json.encode(layout.snapshot()))
assert(layout.restore(scratch_snapshot))
local scratch_windows = {}
for _, w in ipairs(vim.api.nvim_list_wins()) do
    local current = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_buf_get_name(current) == '' and vim.bo[current].modified then
        scratch_windows[#scratch_windows + 1] = current
    end
end
assert(#scratch_windows == 2 and scratch_windows[1] == scratch_windows[2], 'shared unnamed buffer not restored')
assert(vim.api.nvim_buf_get_lines(scratch_windows[1], 0, -1, false)[1] == 'unsaved note')
print('PASS: per-window history, shared/last close, modified safety, settings, auto-close protection, session round-trip and old sessions')
vim.cmd('qa!')
