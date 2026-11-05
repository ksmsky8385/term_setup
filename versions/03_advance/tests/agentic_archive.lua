vim.opt.rtp:prepend(vim.fn.getcwd())
local archive = require('config.agentic_archive')
local original_input = vim.ui.input
for _, case in ipairs({ { 'y', true }, { '', true }, { 'n', false }, { false, false } }) do
    local answer
    local windows = #vim.api.nvim_list_wins()
    vim.ui.input = function(opts, callback)
        assert(opts.prompt:find('Delete test session?', 1, true))
        if case[1] == false then callback(nil) else callback(case[1]) end
    end
    archive.confirm('Delete test session?', function(value) answer = value end)
    assert(answer == case[2])
    assert(#vim.api.nvim_list_wins() == windows, 'confirmation must not create a float')
end
vim.ui.input = original_input
print('archive confirmation: PASS')
local maps, confirm, requests = {}, nil, {}
local picker_options, picker_definition
local selected = { value = { session_id = 'one', title = 'Example', path = '/tmp/example.jsonl' } }
local registry = { sessions = {}, current = function() return nil end }
package.loaded['agentic.session_registry'] = registry
package.loaded['telescope.actions'] = {
    close = function() end,
    select_default = { replace = function(_, fn) maps.enter = fn end },
}
package.loaded['telescope.actions.state'] = { get_selected_entry = function() return selected end }
package.loaded['telescope.themes'] = { get_dropdown = function(opts) return opts end }
package.loaded['telescope.finders'] = { new_table = function(opts) return opts end }
package.loaded['telescope.config'] = { values = { generic_sorter = function() end } }
package.loaded['telescope.previewers'] = { new_buffer_previewer = function(opts) return opts end }
package.loaded['telescope.pickers'] = { new = function(options, opts)
    picker_options, picker_definition = options, opts
    return { find = function()
        maps = {}
        opts.attach_mappings(1, function(mode, lhs, fn) maps[mode .. lhs] = fn end)
    end }
end }
archive.request = function(params, cb)
    requests[#requests + 1] = params
    cb({ items = {} })
end
archive.confirm = function(_, cb) confirm = cb end
archive.show({ provider_name = 'pi-acp' }, function() end)
assert(maps['i<C-a>'] and maps['n<C-a>'] and maps['i<C-o>'])
assert(not maps.na and not maps.nA and not maps.ia and not maps.iA)
assert(picker_options.initial_mode ~= 'normal', 'do not force normal mode')
maps['i<C-a>']()
assert(vim.wait(100, function() return confirm ~= nil end))
assert(#requests == 1, 'archive must wait for confirmation')
confirm(false)
assert(requests[#requests].action == 'list')
maps['i<C-o>']()
assert(vim.wait(100, function() return requests[#requests].archived == true end))
assert(requests[#requests].cwd == nil, 'archives must include all directories')
assert(maps['i<C-r>'] and maps['n<C-x>'])
confirm = nil
maps['n<C-x>']()
assert(vim.wait(100, function() return confirm ~= nil end))
for _, req in ipairs(requests) do assert(req.action == 'list', 'delete before confirmation') end
confirm(false)
confirm = nil
maps['n<C-x>']()
assert(vim.wait(100, function() return confirm ~= nil end))
confirm(true)
assert(requests[#requests - 1].action == 'delete')
assert(requests[#requests - 1].path == '/tmp/example.jsonl')
print('archive picker actions and cancellation: PASS')

vim.o.columns = 100
vim.o.lines = 30
archive.show({ provider_name = 'pi-acp' }, function() end)
assert(picker_options.width == 0.78 and picker_options.height == 0.55)
assert(picker_definition.previewer == false)
vim.o.columns = 160
vim.o.lines = 45
archive.show({ provider_name = 'pi-acp' }, function() end)
assert(picker_options.width == 0.9 and picker_options.height == 0.75)
assert(picker_options.layout_strategy == 'horizontal')
assert(picker_options.layout_config.preview_width == 0.5)
assert(type(picker_definition.previewer) == 'table')
print('original session picker layouts: PASS')
