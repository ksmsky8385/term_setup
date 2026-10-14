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
req('nvim_input_mouse','right','press','',0,points[1],points[2])
vim.wait(30,function() return false end)
assert(not req('nvim_get_mode').blocking, 'menu opened before right button release')
req('nvim_input_mouse','right','drag','',0,points[1],points[2]+1)
req('nvim_input_mouse','right','release','',0,points[1],points[2]+1)
vim.wait(30,function() return false end)
assert(req('nvim_get_mode').blocking, 'menu did not remain open after right-click gesture')
req('nvim_input',vim.api.nvim_replace_termcodes('<Esc>',true,false,true))
vim.wait(20,function() return false end)
assert(lua([[return not vim.tbl_isempty(vim.fn.menu_info('ConfigTreeContext.Copy File','n'))]]))
lua([[vim.cmd('emenu ConfigTreeContext.Split\\ Vertical')]])
assert(lua([[return vim.api.nvim_buf_get_name(0)=='' and vim.api.nvim_buf_get_lines(0,0,-1,false)[1]=='']]),'tree vertical split did not open an empty buffer')
assert(lua([[return #vim.api.nvim_tabpage_list_wins(0)==3]]))
lua([[require('config.tree_menu').run('horizontal')]])
assert(lua([[local tree=require('nvim-tree.api').tree.winid(); local p=vim.api.nvim_win_get_position(tree); local q=vim.api.nvim_win_get_position(0); return q[1]>p[1] and q[2]==p[2] and vim.api.nvim_win_get_width(0)==vim.api.nvim_win_get_width(tree)]]), 'horizontal split must be below the tree, not another editor window')
assert(lua([[return vim.api.nvim_buf_get_name(0)=='' and vim.api.nvim_buf_get_lines(0,0,-1,false)[1]=='' and #vim.api.nvim_tabpage_list_wins(0)==4]]))
-- New files use nvim-tree's own create dialog and actions against the clicked node.
lua([[vim.ui.input=function(_,cb) cb(vim.fn.fnamemodify(path,':h')..'/created.txt') end; require('config.tree_menu').run('create')]])
assert(lua([[return vim.fn.filereadable(vim.fn.fnamemodify(path,':h')..'/created.txt')==1]]))
vim.fn.jobstop(job)
print('PASS: file tree context menu, empty-buffer vertical/horizontal split and file creation')
vim.cmd('qa!')
