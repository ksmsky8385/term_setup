-- Unsaved line changes relative to the last read/write, not the Git index.
local M = {}
local states = {}
function M.count(buf)
    if vim.bo[buf].buftype ~= '' or not vim.bo[buf].modified then return 0, 0 end
    local state = states[buf]
    if not state then
        local path = vim.api.nvim_buf_get_name(buf)
        local ok, lines = pcall(vim.fn.readfile, path)
        state = { baseline = ok and (#lines > 0 and table.concat(lines, '\n') .. '\n' or '') or '' }
        states[buf] = state

    end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    if state.tick ~= tick then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local current = table.concat(lines, '\n') .. '\n'
        if #lines == 1 and lines[1] == '' then current = '' end
        local added, removed = 0, 0
        for _, hunk in ipairs(vim.diff(state.baseline, current, {result_type = 'indices', algorithm = 'histogram'})) do
            removed = removed + hunk[2]
            added = added + hunk[4]
        end
        state.tick, state.added, state.removed = tick, added, removed
    end
    return state.added, state.removed
end
function M.setup()
    vim.api.nvim_create_autocmd({'BufReadPost', 'BufWritePost', 'BufWipeout'}, {
        group = vim.api.nvim_create_augroup('ConfigBufferChangeCounts', {clear = true}),
        callback = function(args)
            states[args.buf] = nil
            if args.event ~= 'BufWipeout' and vim.bo[args.buf].buftype == '' then
                local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
                states[args.buf] = { baseline = (#lines == 1 and lines[1] == '') and '' or table.concat(lines, '\n') .. '\n' }
            end
        end,
    })
end
return M
