local M = {}

local win
local buf

local lines = {
    "",
    "  Neovim Basic",
    "  =============",
    "",
    "  Dashboard / Settings",
    "    Space h             dashboard",
    "    Space ?             this help",
    "    Space Ctrl-s        settings",
    "    Space e             file tree",
    "    Space ff / fg       find files / search text",
    "",
    "  Buffers",
    "    Space bb            pick buffer",
    "    Space bn / bp       next / previous buffer",
    "    Space bm / bw       move / show in another window",
    "    Space bd / bD       delete / force delete buffer",
    "    Space bo / bO       delete other buffers",
    "",
    "  Windows",
    "    Space ww            pick window",
    "    Space wr            swap window label",
    "    Space wv / ws       vertical / horizontal split",
    "    Space wo / wq       only / close window",
    "    Ctrl-h/j/k/l        move between windows",
    "    Alt-h/j/k/l         resize window",
    "",
    "  Floating windows / Tabs / Sessions",
    "    Space 0..9, `       toggle floating slot",
    "    Space Tab Tab       pick tab",
    "    Space Tab n/q       new / close tab",
    "    Space pp            pick session",
    "    Space P<slot>       save session",
    "    Space p<slot>       load session",
    "",
    "  Terminal / Files",
    "    Space tt            terminal buffer",
    "    Space ts / tv       terminal split",
    "    Ctrl-s              save file",
    "    Space q / Q         close / force close",
    "",
    "  Press q, Esc, Space ?, or Space h to close.",
    "",
}

local function close()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end

    win = nil
    buf = nil
end

function M.open()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        return
    end

    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "basic-about"

    local width = math.min(62, math.max(40, vim.o.columns - 4))
    local height = math.min(#lines, math.max(12, vim.o.lines - 4))

    win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "single",
        width = width,
        height = height,
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    })

    for _, lhs in ipairs({ "q", "<Esc>", "<leader>?", "<leader>h" }) do
        vim.keymap.set("n", lhs, close, {
            buffer = buf,
            silent = true,
            nowait = true,
        })
    end
end

function M.toggle_floating()
    if win and vim.api.nvim_win_is_valid(win) then
        close()
    else
        M.open()
    end
end

return M
