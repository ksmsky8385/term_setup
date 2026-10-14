-- Real embedded UI test; requires permission to create RPC pipes.
local job = vim.fn.jobstart({'/usr/bin/nvim','--embed','--headless','-u','NONE','-i','NONE'}, {rpc=true})
local function req(method, ...) return vim.rpcrequest(job, method, ...) end
local function lua(code) return req('nvim_exec_lua', code, {}) end
req('nvim_ui_attach',120,32,{rgb=true})
req('nvim_exec_lua', [[
 vim.opt.rtp:prepend(...)
 vim.o.mouse='a'
 vim.o.showtabline=0
 require('config.toggle_state').write('editor_winbar',true)
 require('config.winbar').setup()
 local dir=vim.fn.tempname()
 vim.fn.mkdir(dir,'p')
 local function file(name)
  local path=dir..'/'..name
  vim.fn.writefile({'text'},path)
  local b=vim.fn.bufadd(path); vim.fn.bufload(b); vim.bo[b].buflisted=true
  return b
 end
 _G.a=file('a.txt'); _G.b=file('b.txt'); _G.c=file('c.txt')
 _G.left=vim.api.nvim_get_current_win()
 vim.api.nvim_win_set_buf(left,a); vim.api.nvim_win_set_buf(left,b)
 vim.cmd('rightbelow vsplit')
 _G.right=vim.api.nvim_get_current_win()
 vim.api.nvim_win_set_buf(right,a); vim.api.nvim_win_set_buf(right,c)
 vim.cmd('redraw!')
]], {vim.fn.getcwd()})
local function click(col, mod)
 req('nvim_input_mouse','left','press',mod or '',0,0,col)
 req('nvim_input_mouse','left','release','',0,0,col)
 vim.wait(30,function() return false end)
end
click(1) -- reveal first entry in the left window
click(6)
assert(lua('return vim.api.nvim_win_get_buf(left)==a'), 'inactive window label click failed')
assert(lua('return vim.api.nvim_win_get_buf(right)==c'), 'other window was changed')
click(13)
assert(lua('return not vim.tbl_contains(require("config.winbar").items(left),a)'), 'close button failed')
assert(lua('return vim.api.nvim_buf_is_valid(a)'), 'shared hidden buffer deleted')
-- Dashboard/tree style local mouse handler must forward clicks to the winbar.
lua([[vim.api.nvim_set_current_win(right); vim.keymap.set('n','<LeftMouse>',function() _G.mousepos=vim.fn.getmousepos(); require('config.winbar').forward_mouse('<LeftMouse>') end,{buffer=true})]])
click(6)
assert(lua('return vim.api.nvim_get_current_win()==left'), 'buffer-local mouse forwarding failed: '..vim.inspect(lua('return _G.mousepos')))
lua([[vim.api.nvim_set_current_win(right); vim.o.shell='/bin/sh'; vim.cmd('terminal'); vim.cmd('startinsert')]])
vim.wait(30,function() return false end)
assert(lua('return vim.wo[right].winbar ~= ""'), 'terminal winbar missing')
click(6)
assert(lua('return vim.api.nvim_get_current_win()==left'), 'terminal input mode mouse switching failed')
vim.fn.jobstop(job)
print('PASS: real winbar mouse selection, close, cross-window isolation, hidden reference protection and local mouse forwarding')
vim.cmd('qa!')
