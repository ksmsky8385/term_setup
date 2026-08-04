local M = {}

local function valid_window(win)
    return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function notify_warn(message)
    vim.notify(message, vim.log.levels.WARN)
end

local function swap_directory_path(directory, path)
    local expanded = vim.fn.expand(directory)

    if expanded == "." then
        return vim.fn.fnamemodify(path, ":p:h")
    end

    return expanded:gsub("[/\\]+$", "")
end

local function swap_file_names(path)
    local absolute = vim.fn.fnamemodify(path, ":p")
    local basename = vim.fn.fnamemodify(path, ":t")
    local encoded = absolute:gsub("[/\\:]", "%%")

    return { encoded, "." .. basename, basename }
end

function M.find(path)
    for _, directory in ipairs(vim.split(vim.o.directory, ",", { plain = true, trimempty = true })) do
        local swap_dir = swap_directory_path(directory, path)

        if swap_dir ~= "" and vim.fn.isdirectory(swap_dir) == 1 then
            for _, name in ipairs(swap_file_names(path)) do
                local matches = vim.fn.globpath(swap_dir, name .. ".sw?", false, true)

                if type(matches) == "table" and #matches > 0 then
                    return matches[1]
                end
            end
        end
    end

    return nil
end

local function prompt_swap_choice(path, swap_name, allow_recover)
    local choices = "&Skip\n&Open anyway\n&Delete swap and open"

    if allow_recover then
        choices = choices .. "\n&Recover"
    end

    local choice = vim.fn.confirm(
        "Swap file exists:\n" .. path .. "\n\nSwap file:\n" .. swap_name,
        choices,
        1
    )

    if choice == 2 then
        return "open"
    end

    if choice == 3 then
        return "delete"
    end

    if allow_recover and choice == 4 then
        return "recover"
    end

    return "skip"
end

function M.load_buffer(path, opts)
    opts = opts or {}

    local buf = vim.fn.bufadd(path)

    if vim.fn.bufloaded(buf) == 1 then
        vim.bo[buf].buflisted = true
        return buf, nil
    end

    local swap_name = M.find(path)

    if type(swap_name) == "string" and swap_name ~= "" then
        local choice = prompt_swap_choice(path, swap_name, valid_window(opts.win))

        if choice == "skip" then
            notify_warn("Skipped file with swap: " .. path)
            return nil, nil
        end

        if choice == "delete" then
            local deleted = vim.fn.delete(swap_name)

            if deleted ~= 0 then
                notify_warn("Could not delete swap file: " .. swap_name)
                return nil, nil
            end
        elseif choice == "recover" then
            if valid_window(opts.win) then
                pcall(vim.api.nvim_set_current_win, opts.win)
            end

            local recovered = pcall(vim.cmd, "recover " .. vim.fn.fnameescape(path))

            if recovered then
                local recovered_buf = vim.api.nvim_get_current_buf()

                vim.bo[recovered_buf].buflisted = true
                return recovered_buf, nil
            end

            notify_warn("Could not recover file: " .. path)
            return nil, nil
        elseif choice == "open" then
            vim.bo[buf].swapfile = false
        end
    end

    local ok, err = pcall(vim.fn.bufload, buf)

    if not ok then
        notify_warn("Skipped file during load: " .. path)
        return nil, err
    end

    vim.bo[buf].buflisted = true

    return buf, nil
end

return M
