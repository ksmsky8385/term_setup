local M = {}
local context
local menu_name = 'ConfigTreeContext'
local entries = {
    {'New File or Folder', 'create'},
    {'Rename', 'rename'},
    {'Copy File', 'copy'},
    {'Cut File', 'cut'},
    {'Paste', 'paste'},
    {'Go to Trash', 'trash'},
    {'Delete', 'delete'},
    {'-paths-', false},
    {'Copy Filename', 'filename'},
    {'Copy Relative Path', 'relative'},
    {'Copy Absolute Path', 'absolute'},
    {'-split-', false},
    {'Split Vertical', 'vertical'},
    {'Split Horizontal', 'horizontal'},
}

function M.run(action)
    if not context or not vim.api.nvim_win_is_valid(context.win) then return end
    local api = require('nvim-tree.api')
    local node = context.node
    if not node then return end
    vim.api.nvim_set_current_win(context.win)
    if action == 'vertical' or action == 'horizontal' then
        -- :new avoids ever cloning the tree buffer into the new editor window.
        vim.cmd(action == 'vertical' and 'rightbelow vnew' or 'rightbelow new')
        local win = vim.api.nvim_get_current_win()
        vim.bo.buflisted = false
        require('config.winbar').clear_window(win)
        return
    end
    local actions = {
        create = api.fs.create, rename = api.fs.rename, copy = api.fs.copy.node,
        cut = api.fs.cut, paste = api.fs.paste, trash = api.fs.trash, delete = api.fs.remove,
        filename = api.fs.copy.filename, relative = api.fs.copy.relative_path,
        absolute = api.fs.copy.absolute_path,
    }
    if actions[action] then actions[action](node) end
end

function M.attach(buf)
    local pending
    if not M.initialized then
        vim.api.nvim_create_user_command('TreeContextAction', function(args) M.run(args.args) end, {nargs = 1})
        for index, entry in ipairs(entries) do
            local path = menu_name .. '.' .. entry[1]:gsub(' ', '\\ ')
            vim.cmd('nnoremenu <silent> 500.' .. index .. ' ' .. path .. ' '
                .. (entry[2] and ('<Cmd>TreeContextAction ' .. entry[2] .. '<CR>') or '<Nop>'))
        end
        M.initialized = true
    end
    vim.keymap.set('n', '<RightMouse>', function()
        pending = nil
        local mouse = vim.fn.getmousepos()
        if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) or mouse.line < 1 then return end
        if vim.bo[vim.api.nvim_win_get_buf(mouse.winid)].filetype ~= 'NvimTree' then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<RightMouse>', true, false, true), 'ni', false)
            return
        end
        vim.api.nvim_set_current_win(mouse.winid)
        vim.api.nvim_win_set_cursor(mouse.winid, {mouse.line, 0})
        pending = {win = mouse.winid, node = require('nvim-tree.api').tree.get_node_under_cursor()}
    end, {buffer = buf, silent = true, desc = 'File tree context menu'})
    -- Open after the initiating gesture ends, so its drag/release events
    -- cannot be interpreted as input to the newly opened modal menu.
    vim.keymap.set('n', '<RightDrag>', '<Nop>', {buffer = buf, silent = true})
    vim.keymap.set('n', '<RightRelease>', function()
        local clicked = pending
        pending = nil
        if not clicked or not clicked.node or not vim.api.nvim_win_is_valid(clicked.win) then return end
        local mouse = vim.fn.getmousepos()
        if mouse.winid ~= clicked.win then return end
        context = clicked
        vim.cmd('popup ' .. menu_name)
    end, {buffer = buf, silent = true, desc = 'Open file tree context menu on release'})
end
return M
