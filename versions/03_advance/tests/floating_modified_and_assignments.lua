vim.opt.rtp:prepend(vim.fn.getcwd())
require('config.toggle_state').write('editor_winbar',true)
local bar=require('config.winbar');bar.setup()
local path=vim.fn.tempname()..'.txt';vim.fn.writefile({'first','second'},path)
vim.cmd.edit(path)
local buf=vim.api.nvim_get_current_buf();local main=vim.api.nvim_get_current_win();bar.track(main)
vim.cmd.enew();vim.api.nvim_buf_set_name(0,vim.fn.tempname()..'.txt');bar.track(main)
local function display()
 local telescope={make_entry={gen_from_buffer=function() return function(e) return {bufnr=e.bufnr,display='file'} end end}}
 local maker=require('config.buffers.picker_entries').entry_maker({},telescope)
 local entry=maker({bufnr=buf})
 return type(entry.display)=='function' and entry.display(entry) or entry.display
end
local label=require('config.window_picker').label_for_window(main,require('config.buffers.policy').window_picker_exclude)
assert(display():find('['..label..']',1,true),'hidden winbar assignment missing')
require('config.toggle_state').write('editor_winbar',false)
assert(not display():find('['..label..']',1,true),'disabled winbar leaked assignment')
require('config.toggle_state').write('editor_winbar',true)
require('config.toggle_state').write('editor_winbar',false);bar.refresh()
local fw=require('config.floating.window')
local win=fw.open('1',buf)
local function title()
 local chunks=vim.api.nvim_win_get_config(win).title
 local text='';for _,chunk in ipairs(chunks or {}) do text=text..chunk[1] end
 return text
end
vim.api.nvim_buf_set_lines(buf,0,1,false,{'replacement','added'})
vim.api.nvim_exec_autocmds('TextChanged',{buffer=buf})
vim.wait(100,function() return title():find('+2 -1',1,true)~=nil end)
assert(title():find('+2 -1',1,true),'floating title missing diff')
vim.cmd.write();vim.wait(100,function() return not title():find('+2',1,true) end)
assert(not title():find('+2',1,true),'save did not clear title')
vim.bo[buf].modified=true
vim.api.nvim_exec_autocmds('BufModifiedSet',{buffer=buf})
vim.wait(100,function() return title():find('●',1,true)~=nil end)
assert(title():find('●',1,true),'modified-only indicator missing')
print('PASS: hidden winbar ownership, disabled setting, floating diff/title refresh and modified-only dot')
vim.cmd('qa!')
