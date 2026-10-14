vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.shell = '/bin/sh'
local bar = require('config.winbar')
require('config.toggle_state').write('editor_winbar',true)
bar.setup()
require('config.terminal').setup()
vim.api.nvim_set_hl(0,'Normal',{fg=0xeeeeee,bg=0x111111})
vim.api.nvim_set_hl(0,'DiagnosticInfo',{fg=0x55aaff})
vim.api.nvim_exec_autocmds('ColorScheme',{})
local active=vim.api.nvim_get_hl(0,{name='ConfigWinbarActive'})
local inactive=vim.api.nvim_get_hl(0,{name='ConfigWinbarInactive'})
assert(active.bg==0x111111 and active.bold and not active.underline and not inactive.underline and inactive.bg ~= 0x111111)
local left=vim.api.nvim_get_current_win()
vim.cmd('terminal')
local term=vim.api.nvim_get_current_buf()
assert(vim.tbl_contains(bar.items(left),term),'terminal was not tracked')
assert(vim.wo[left].winbar~='','terminal winbar missing')
assert(bar.render():find('ConfigWinbarActive',1,true))
assert(bar.render():find('Terminal '..term,1,true))
vim.cmd('vsplit')
local right=vim.api.nvim_get_current_win()
assert(bar.close(left,term))
assert(vim.fn.jobwait({vim.b[term].terminal_job_id},0)[1]==-1,'shared terminal stopped')
local prompted=false
vim.ui.select=function(_,_,cb) prompted=true;cb('Cancel') end
assert(not bar.close(right,term) and prompted)
assert(vim.tbl_contains(bar.items(right),term))
-- One hidden terminal and one shared visible terminal survive a layout round trip.
vim.cmd('enew')
vim.cmd('terminal')
local second=vim.api.nvim_get_current_buf()
vim.api.nvim_win_set_buf(left,second)
local layout=require('config.sessions.layout')
local snapshot=vim.json.decode(vim.json.encode(layout.snapshot()))
assert(layout.restore(snapshot))
local wins=vim.api.nvim_tabpage_list_wins(0)
assert(vim.api.nvim_win_get_buf(wins[1])==vim.api.nvim_win_get_buf(wins[2]),'shared visible terminal duplicated')
local hidden
for _,win in ipairs(wins) do
 for _,buf in ipairs(bar.items(win)) do
  if vim.b[buf].pending_terminal_restore then hidden=buf end
 end
end
assert(hidden,'hidden terminal history not restored')
bar.select(wins[1],hidden)
assert(vim.bo[hidden].buftype=='terminal' and not vim.b[hidden].pending_terminal_restore)
assert(vim.wo[wins[1]].winbar~='')
assert(bar.close(wins[1],hidden,true))
assert(not vim.api.nvim_buf_is_valid(hidden))
print('PASS: theme accent/background boundary, terminals, shared close, running-job confirmation, visible/hidden terminal session restore')
vim.cmd('qa!')
