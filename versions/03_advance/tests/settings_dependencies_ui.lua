local job=vim.fn.jobstart({'/usr/bin/nvim','--embed','--headless','-u','NONE','-i','NONE'},{rpc=true})
local function req(method,...) return vim.rpcrequest(job,method,...) end
local function lua(code) return req('nvim_exec_lua',code,{}) end
req('nvim_ui_attach',120,35,{rgb=true})
req('nvim_exec_lua',[[
vim.opt.rtp:prepend(...)
for _,plugin in ipairs({'telescope.nvim','plenary.nvim'}) do vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/'..plugin)) end
vim.o.mouse='a'
require('telescope').setup({})
require('config.toggle_state').write('editor_winbar',false)
require('config.settings').open('editor')
]],{vim.fn.getcwd()})
vim.wait(150,function() return false end)
local point=lua([[
local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
for i=1,p.manager:num_results() do
 local e=p.manager:get_entry(i)
 if e.value.key=='winbar_compress' then
  assert(e.value.disabled and e.value.label:find('ㄴ',1,true))
  local parent=p.manager:get_entry(i+1); assert(parent.value.key=='winbar','dependency not below parent')
  local row=p:get_row(i)
  assert(p:get_row(i+1)<row,'parent is not visually above child')
  p:set_selection(row)
  local selected=require('telescope.actions.state').get_selected_entry()
  assert(not selected.value.disabled,'disabled row selected')
  local pos=vim.api.nvim_win_get_position(p.results_win)
  return {pos[1]+row,pos[2]+5}
 end
end
error('dependent entry missing')
]])
for _=1,2 do
 req('nvim_input_mouse','left','press','',0,point[1],point[2])
 req('nvim_input_mouse','left','release','',0,point[1],point[2])
end
vim.wait(60,function() return false end)
assert(lua([[return require('config.editor_settings').get('winbar')==false and require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())~=nil]]),'disabled click activated a setting')
vim.fn.jobstop(job)
print('PASS: dependent settings grouped, disabled keyboard selection skipped, disabled mouse click ignored')
vim.cmd('qa!')
