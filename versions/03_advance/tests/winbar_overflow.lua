vim.opt.rtp:prepend(vim.fn.getcwd())
require('config.toggle_state').write('editor_winbar',true)
require('config.toggle_state').write('editor_winbar_compress',false)
local bar=require('config.winbar');bar.setup();require('config.keymaps')
vim.cmd('vnew');vim.api.nvim_win_set_width(0,45)
local win=vim.api.nvim_get_current_win()
local function display()
 return vim.api.nvim_eval_statusline(bar.render(),{winid=win,use_winbar=true}).str
end
local bufs={}
for i=1,4 do
 local b=vim.api.nvim_create_buf(true,false);bufs[i]=b
 vim.api.nvim_buf_set_name(b,'/tmp/long_filename_number_'..i..'.lua')
 vim.api.nvim_win_set_buf(win,b);bar.track(win)
end
assert(display():find('number_4',1,true),'new current buffer not revealed')
assert(display():find('‹',1,true) and not display():find('›',1,true),'arrow end bounds incorrect')
require('config.toggle_state').write('editor_winbar_compress',true)
local compact=display()
assert(compact:find('...',1,true),'names did not compress')
-- With two short boxes there should be no arrows or scroll callbacks.
bar.clear_window(win)
for i=1,2 do vim.api.nvim_win_set_buf(win,bufs[i]);bar.track(win) end
assert(not bar.render():find('ConfigWinbarScroll',1,true),'fitting compressed boxes still have arrows')
local t=vim.api.nvim_create_buf(true,false);vim.api.nvim_win_set_buf(win,t)
bar.track(win)
vim.fn.termopen({'sh','-c','sleep 2'})
vim.wait(30,function() return false end)
require('config.toggle_state').write('editor_winbar_compress',false)
bar.track(win)
assert(display():find('Terminal',1,true),'terminal box not revealed')
vim.fn.jobstop(vim.b[t].terminal_job_id)
-- Last mouse close uses the same empty-window policy as q.
bar.clear_window(win);vim.api.nvim_win_set_buf(win,bufs[1]);bar.track(win)
local old=vim.fn.getmousepos;vim.fn.getmousepos=function() return {winid=win} end
_G.ConfigWinbarClose(bufs[1],1,'l')
vim.fn.getmousepos=old
assert(not vim.api.nvim_win_is_valid(win),'last mouse close did not close split')
local dashboard=false
vim.api.nvim_create_user_command('DashboardHome',function() dashboard=true end,{})
local main=vim.api.nvim_get_current_win();bar.clear_window(main)
vim.api.nvim_win_set_buf(main,bufs[2]);bar.track(main)
vim.fn.getmousepos=function() return {winid=main} end
_G.ConfigWinbarClose(bufs[2],1,'l');vim.fn.getmousepos=old
assert(dashboard,'last mouse close did not open dashboard')
print('PASS: compression, directional arrows, terminal reveal and mouse last-close policy')
vim.cmd('qa!')
