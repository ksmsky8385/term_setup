local job=vim.fn.jobstart({'/usr/bin/nvim','--embed','--headless','-u','NONE','-i','NONE'},{rpc=true})
local function req(method,...) return vim.rpcrequest(job,method,...) end
local function lua(code) return req('nvim_exec_lua',code,{}) end
req('nvim_ui_attach',140,42,{rgb=true})
req('nvim_exec_lua',[[
vim.opt.rtp:prepend(...)
for _,name in ipairs({'telescope.nvim','plenary.nvim'}) do vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/'..name)) end
require('config.toggle_state').write('editor_winbar',true)
require('config.winbar').setup();require('config.keymaps')
require('plugins.telescope').config()
local dir=vim.fn.tempname();vim.fn.mkdir(dir,'p');vim.fn.writefile({'test'},dir..'/pick.lua');vim.cmd.cd(dir)
local b=vim.api.nvim_create_buf(true,false);vim.api.nvim_buf_set_name(b,dir..'/source.lua')
require('config.floating').open_buffer(b,{slot_id='1'})
require('config.floating').split('vertical')
_G.pane=vim.api.nvim_get_current_win()
vim.fn.maparg('<leader>ff','n',false,true).callback()
]],{vim.fn.getcwd()})
vim.wait(200,function() return false end)
assert(lua([[
local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
require('config.winbar').refresh()
require('config.floating.window').apply_layout('1')
for _,w in ipairs({p.prompt_win,p.results_win,p.preview_win}) do
 if w then assert(vim.api.nvim_win_get_config(w).zindex>vim.api.nvim_win_get_config(pane).zindex,'picker is behind editor pane') end
end
return true
]]))
req('nvim_input','pick.lua')
vim.wait(120,function() return false end)
req('nvim_input','\r')
vim.wait(120,function() return false end)
assert(lua([[return vim.api.nvim_get_current_win()==pane and vim.api.nvim_buf_get_name(0):match('/pick.lua$')~=nil]]),'file did not open in originating floating pane')
vim.fn.jobstop(job);print('PASS: Telescope stays above floating panes after refresh/layout and opens in source pane');vim.cmd('qa!')
