-- XDG_STATE_HOME=/tmp/agentic-limits-test nvim --headless -u NONE -i NONE -l tests/agentic_limits.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/agentic.nvim')
local settings = require('config.sidebar_settings')
local limits = require('config.agentic_limits')
assert(settings.set('agentic_usage', true))
local spec = dofile('lua/plugins/agentic.lua')
vim.g.mapleader = ' '
spec.init()
local visible = vim.api.nvim_get_current_tabpage()
local refreshes = 0
local agent_config = require('agentic.config')
local SessionState = require('agentic.acp.session_state')
local state = SessionState:new({}, agent_config.acp_providers['pi-acp'].name)
local session = { session_id = 'one', provider_name = 'pi-acp', session_state = state,
    widget = { get_visible_tab_id = function() return visible end,
        schedule_header_refresh = function() refreshes = refreshes + 1 end } }
package.loaded['agentic.session_registry'] = { sessions = { [1] = session } }
local calls, callback = 0, nil
limits.query = function(cb) calls = calls + 1; callback = cb end
local function answer(five, weekly)
    local before = refreshes
    callback({ rateLimits = {
        primary = { usedPercent = 100 - five, windowDurationMins = 300 },
        secondary = { usedPercent = 100 - weekly, windowDurationMins = 10080 },
    } })
    assert(vim.wait(100, function() return refreshes > before end))
end
local function header() return spec.opts.headers.chat(nil, state) end
assert(limits.interval() == 15000)
limits.tick(0)
assert(calls == 1)
limits.tick(15000)
assert(calls == 1, 'must not overlap account requests')
answer(51, 50)
assert(header():find('5h %%#AgenticUsageHeader#51%%%%'))
assert(header():find('Weekly %%#AgenticUsageLow#50%%%%'))
limits.tick(14999)
assert(calls == 1)
limits.tick(15000)
assert(calls == 2)
answer(20, 21)
assert(header():find('5h %%#AgenticUsageCritical#20%%%%'))
assert(header():find('Weekly %%#AgenticUsageLow#21%%%%'))
local rendered = vim.api.nvim_eval_statusline(header(), { use_winbar = true, maxwidth = 100 }).str
assert(rendered == 'pi acp - Left: 5h 20% | Weekly 21%', rendered)
local codex_state = SessionState:new({}, agent_config.acp_providers['codex-acp'].name)
assert(limits.header(nil, codex_state) ~= '', 'Codex display name must render')
assert(limits.header(nil, SessionState:new({}, 'Other ACP')) == '')
local base = vim.api.nvim_get_hl(0, { name = 'AgenticUsageHeader' })
local low = vim.api.nvim_get_hl(0, { name = 'AgenticUsageLow' })
local critical = vim.api.nvim_get_hl(0, { name = 'AgenticUsageCritical' })
assert(base.fg == 0xffffff and low.fg == 0xffff00 and critical.fg == 0xff0000)
assert(base.bg == low.bg and low.bg == critical.bg)
session.is_generating = true
assert(limits.interval() == 5000)
limits.tick(19999)
assert(calls == 2)
limits.tick(20000)
assert(calls == 3)
answer(10, 70)
session.is_generating = false
limits.tick(25000)
assert(calls == 3, 'completion must return to idle interval')
limits.tick(35000)
assert(calls == 4)
answer(70, 90)
visible = nil
limits.tick(50000)
assert(calls == 4 and limits.interval() == nil, 'hidden idle widget must not poll')
visible = vim.api.nvim_get_current_tabpage()
limits.tick(50001)
assert(calls == 5, 'reopening must refresh')
answer(80, 90)
-- Other sessions share one account request rather than polling separately.
package.loaded['agentic.session_registry'].sessions[2] = session
limits.tick(65001)
assert(calls == 6)
answer(80, 90)
limits.toggle()
assert(settings.get('agentic_usage') == false and header() == '')
local hidden_calls = calls
limits.tick(90000, true)
assert(calls == hidden_calls)
package.loaded['config.sidebar_settings'] = nil
settings = require('config.sidebar_settings')
assert(settings.get('agentic_usage') == false, 'toggle must persist in JSON')
-- Buffer-local mappings only; normal files and other Agentic panels are untouched.
for _, ft in ipairs({ 'AgenticChat', 'AgenticInput', 'markdown', 'AgenticFiles' }) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = ft
    local mapping = vim.fn.maparg(' au', 'n', false, true)
    if ft == 'AgenticChat' or ft == 'AgenticInput' then
        assert(mapping.buffer == 1 and type(mapping.callback) == 'function', ft)
    else
        assert(next(mapping) == nil, ft .. ' must not have au mapping')
    end
    assert(#vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {}) == 0, 'no warning text')
end
for _, key in ipairs(spec.keys) do assert(key[1] ~= '<leader>au', 'no global au') end
print('usage header colors, adaptive polling, local toggle and persistence: PASS')
