local M = {}
local popup
local group
local namespace = vim.api.nvim_create_namespace("file_path_preview")

local function close()
    vim.on_key(nil, namespace)
    if group then
        vim.api.nvim_del_augroup_by_id(group)
        group = nil
    end
    local win = popup
    popup = nil
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

function M.toggle()
    if popup and vim.api.nvim_win_is_valid(popup) then
        close()
        return
    end
    close()

    local owner = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or path == "" then
        return
    end

    local width = math.max(1, math.min(vim.fn.strdisplaywidth(path), vim.api.nvim_win_get_width(owner) - 2))
    local height = math.max(1, math.min(
        math.ceil(vim.fn.strdisplaywidth(path) / width),
        vim.api.nvim_win_get_height(owner) - 2
    ))
    local preview = vim.api.nvim_create_buf(false, true)
    vim.bo[preview].bufhidden = "wipe"
    vim.bo[preview].swapfile = false
    vim.api.nvim_buf_set_lines(preview, 0, -1, false, { path })
    vim.bo[preview].modifiable = false
    popup = vim.api.nvim_open_win(preview, false, {
        relative = "win",
        win = owner,
        row = 0,
        col = 0,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        focusable = false,
    })
    vim.wo[popup].wrap = true

    group = vim.api.nvim_create_augroup("FilePathPreview", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "InsertEnter", "VimResized", "WinResized", "BufFilePost" }, {
        group = group,
        callback = close,
    })
    local current_popup = popup
    vim.on_key(function(key)
        if key == "\27" then
            vim.schedule(function()
                if popup == current_popup then
                    close()
                end
            end)
        end
    end, namespace)
end

return M
