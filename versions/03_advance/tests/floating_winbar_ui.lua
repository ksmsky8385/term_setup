local job=vim.fn.jobstart({'/usr/bin/nvim','--embed','--headless','-u','NONE','-i','NONE'},{rpc=true})
local function req(method,...) return vim.rpcrequest(job,method,...) end
local function lua(code) return req('nvim_exec_lua',code,{}) end
req('nvim_ui_attach',140,42,{rgb=true})
req('nvim_exec_lua',[[
vim.opt.rtp:prepend(...);vim.o.mouse='a'
require('config.toggle_state').write('editor_winbar',true)
require('config.winbar').setup();require('config.keymaps')
local function file(name)
 local b=vim.api.nvim_create_buf(true,false);vim.api.nvim_buf_set_name(b,'/tmp/'..name);return b
end
_G.a=file('a.lua');_G.b=file('b.lua')
local f=require('config.floating');f.open_buffer(a,{slot_id='1'});f.open_buffer(b,{slot_id='1'})
_G.w=vim.api.nvim_get_current_win();vim.cmd('redraw!')
]],{vim.fn.getcwd()})
vim.wait(80,function() return false end)
local pt=lua([[local p=vim.fn.screenpos(w,1,1);return {p.row-2,vim.api.nvim_win_get_position(w)[2]+1+5+5}]])
req('nvim_input_mouse','left','press','',0,pt[1],pt[2]);req('nvim_input_mouse','left','release','',0,pt[1],pt[2])
vim.wait(40,function() return false end)
assert(lua([[return vim.api.nvim_win_get_buf(w)==a]]),'floating winbar click failed')
-- The first caption is "icon a.lua"; close follows the padded label.
req('nvim_input_mouse','left','press','',0,pt[1],pt[2]+8);req('nvim_input_mouse','left','release','',0,pt[1],pt[2]+8)
vim.wait(40,function() return false end)
assert(lua([[return not vim.api.nvim_buf_is_valid(a) and vim.api.nvim_win_get_buf(w)==b]]),'floating close failed')
vim.wait(550,function() return false end)
req('nvim_input_mouse','left','press','',0,pt[1],pt[2]+8);req('nvim_input_mouse','left','release','',0,pt[1],pt[2]+8)
vim.wait(40,function() return false end)
assert(lua([[return not vim.api.nvim_win_is_valid(w)]]),'last mouse close did not close float')
lua([[
local f=require('config.floating')
_G.dragbuf=vim.api.nvim_create_buf(true,false);vim.api.nvim_buf_set_name(dragbuf,'/tmp/float-drag.lua')
f.open_buffer(dragbuf,{slot_id='2'});_G.source=vim.api.nvim_get_current_win()
local _,target=f.split('vertical');_G.target=target
vim.cmd('redraw!')
]])
vim.wait(550,function() return false end)
local points=lua([[
local p=vim.fn.screenpos(source,1,1);local q=vim.api.nvim_win_get_position(source)
local t=vim.fn.screenpos(target,1,1)
return {p.row-2,q[2]+6+8,t.row,t.col+1}
]])
req('nvim_input_mouse','left','press','',0,points[1],points[2])
vim.wait(30,function() return false end)
req('nvim_input_mouse','left','drag','',0,points[3],points[4])
vim.wait(30,function() return false end)
req('nvim_input_mouse','left','release','',0,points[3],points[4])
vim.wait(60,function() return false end)
assert(lua([[return vim.api.nvim_win_get_buf(target)==dragbuf and #require('config.winbar').items(source)==0]]),'drag into empty floating pane failed')
vim.fn.jobstop(job);print('PASS: actual floating winbar selection, close, last-entry close and drag into empty pane');vim.cmd('qa!')
