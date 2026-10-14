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

local function drag_mouse(from_col, to_row, to_col)
 req('nvim_input_mouse','left','press','',0,0,from_col)
 vim.wait(20,function() return false end)
 req('nvim_input_mouse','left','drag','',0,to_row,to_col)
 req('nvim_input_mouse','left','release','',0,to_row,to_col)
 vim.wait(50,function() return false end)
end
drag_mouse(6,0,32)
assert(lua('return vim.deep_equal(require("config.winbar").items(left),{b,a})'), 'same-window reorder failed')
drag_mouse(21,3,70)
assert(lua('return vim.api.nvim_win_get_buf(right)==a'), 'cross-window display failed')
assert(lua('return vim.deep_equal(require("config.winbar").items(left),{b})'), 'source retained transferred entry')
assert(lua('return vim.api.nvim_buf_is_valid(a)'), 'transferred buffer was deleted')
-- Invalid drop on the command line leaves ownership intact.
drag_mouse(6,31,4)
assert(lua('return vim.deep_equal(require("config.winbar").items(left),{b})'))
-- Reproduce the last-buffer round-trip: right owns one item, then becomes empty.
lua([[local bar=require('config.winbar'); local t=vim.api.nvim_create_buf(true,false); vim.api.nvim_buf_set_name(t,vim.fn.tempname()..'.txt'); vim.api.nvim_win_set_buf(right,t); bar.restore_window(right,{},nil); _G.sole=t; assert(#bar.items(right)==1); assert(bar.drop(right,t,left)); assert(#bar.items(right)==0); assert(vim.bo[vim.api.nvim_win_get_buf(right)].buftype==''); assert(bar.drop(left,t,right)); assert(vim.api.nvim_win_get_buf(right)==t)]])
vim.fn.jobstop(job)
print('PASS: real drag reorder, cross-window transfer, deduplication and invalid-drop cancellation')
vim.cmd('qa!')
