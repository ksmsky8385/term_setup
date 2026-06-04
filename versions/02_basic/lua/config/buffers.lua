local M = {}

local function valid_listed_buffer(buf)
    return buf
        and vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
end

local function listed_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if valid_listed_buffer(buf) then
            table.insert(buffers, buf)
        end
    end

    return buffers
end

local function buffer_name(buf)
    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":t")
end

local function replacement_buffer(current)
    local alternate = vim.fn.bufnr("#")

    if alternate ~= current and valid_listed_buffer(alternate) then
        return alternate
    end

    for _, buf in ipairs(listed_buffers()) do
        if buf ~= current then
            return buf
        end
    end

    return nil
end

local function delete_buffer(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return true
    end

    if vim.bo[buf].modified and not force then
        vim.notify(
            "Buffer has unsaved changes: " .. buffer_name(buf),
            vim.log.levels.WARN
        )
        return false
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
        force = force,
    })

    if not ok then
        vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
    end

    return ok
end

function M.pick()
    local ok, builtin = pcall(require, "telescope.builtin")

    if ok then
        builtin.buffers({
            sort_mru = true,
            ignore_current_buffer = false,
        })
        return
    end

    vim.cmd("buffers")
end

function M.next()
    local ok = pcall(vim.cmd, "bnext")

    if not ok then
        vim.notify("No next buffer", vim.log.levels.INFO)
    end
end

function M.previous()
    local ok = pcall(vim.cmd, "bprevious")

    if not ok then
        vim.notify("No previous buffer", vim.log.levels.INFO)
    end
end

function M.delete_current(force)
    local current = vim.api.nvim_get_current_buf()

    local replacement = replacement_buffer(current)

    if replacement then
        vim.api.nvim_win_set_buf(0, replacement)
    else
        vim.cmd("enew")
    end

    delete_buffer(current, force)
end

function M.delete_others(force)
    local current = vim.api.nvim_get_current_buf()

    for _, buf in ipairs(listed_buffers()) do
        if buf ~= current then
            delete_buffer(buf, force)
        end
    end
end

return M
