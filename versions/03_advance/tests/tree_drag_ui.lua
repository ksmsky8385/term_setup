local job=vim.fn.jobstart({'/usr/bin/nvim','--embed','--headless','-u','NONE','-i','NONE'},{rpc=true})
local function req(method,...) return vim.rpcrequest(job,method,...) end
local function lua(code) return req('nvim_exec_lua',code,{}) end
req('nvim_ui_attach',120,32,{rgb=true})
req('nvim_exec_lua',[[
 vim.opt.rtp:prepend(...)
 vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/nvim-tree.lua'))
 vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/nvim-web-devicons'))
 vim.o.mouse='a'
 require('config.toggle_state').write('editor_winbar',true)
 require('config.winbar').setup()
 require('plugins.nvim-tree').config()
 _G.target=vim.api.nvim_get_current_win()
 local dir=vim.fn.tempname();vim.fn.mkdir(dir,'p')
 _G.path=dir..'/drag-target.txt';vim.fn.writefile({'hello'},path)
 vim.cmd('cd '..vim.fn.fnameescape(dir))
 vim.g.current_workspace_root=dir
 require('nvim-tree.api').tree.open({path=dir})
 vim.cmd('redraw!')
]],{vim.fn.getcwd()})
vim.wait(100,function() return false end)
local points=lua([[
 local tree=require('nvim-tree.api').tree.winid()
 local pos=vim.api.nvim_win_get_position(tree)
 local targetpos=vim.api.nvim_win_get_position(target)
 local lines=vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(tree),0,-1,false)
 for i,line in ipairs(lines) do
  if line:find('drag-target.txt',1,true) then return {pos[1]+i-1,pos[2]+5,targetpos[1]+3,targetpos[2]+5} end
 end
 error('tree file not rendered')
]])
local modifier=vim.env.TREE_DRAG_CLICKS or ''
req('nvim_input_mouse','left','press',modifier,0,points[1],points[2])
vim.wait(20,function() return false end)
req('nvim_input_mouse','left','drag',modifier,0,points[3],points[4])
vim.wait(20,function() return false end)
assert(lua([[return not vim.fn.mode():match('[vV]') and vim.fn.mode() ~= string.char(22)]]),'drag entered Visual mode')
req('nvim_input_mouse','left','release',modifier,0,points[3],points[4])
vim.wait(80,function() return false end)
assert(lua('return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target))==path'),'tree drop did not open file')
assert(lua('return vim.tbl_contains(require("config.winbar").items(target),vim.api.nvim_win_get_buf(target))'))
vim.fn.jobstop(job)
print('PASS: actual nvim-tree file drag opens file in target window and adds winbar entry')
vim.cmd('qa!')
