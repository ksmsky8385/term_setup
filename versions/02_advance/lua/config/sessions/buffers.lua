local M = {}

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function buffer_name(buf)
    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":~:.")
end

function M.current_files()
    local files = {}
    local seen = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)

        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.bo[buf].buftype ~= "terminal"
            and name ~= ""
            and not seen[name]
        then
            table.insert(files, name)
            seen[name] = true
        end
    end

    table.sort(files)

    return files
end

local function session_load_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_valid(buf)
            and (
                vim.bo[buf].buflisted
                or vim.bo[buf].buftype == "terminal"
            )
        then
            table.insert(buffers, buf)
        end
    end

    return buffers
end

local function session_load_blockers(buffers)
    local blockers = {}

    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            if vim.bo[buf].modified then
                table.insert(blockers, "Unsaved changes: " .. buffer_name(buf))
            elseif vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) then
                table.insert(blockers, "Running terminal: " .. buffer_name(buf))
            end
        end
    end

    return blockers
end

local function clear_session_load_buffers(buffers, force)
    vim.cmd("enew")

    local keep = vim.api.nvim_get_current_buf()

    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) and buf ~= keep then
            if force and vim.bo[buf].buftype == "terminal" then
                local job_id = vim.b[buf].terminal_job_id

                if terminal_job_running(buf) then
                    pcall(vim.fn.jobstop, job_id)
                end
            end

            local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
                force = force,
            })

            if not ok then
                return false, "Failed to delete " .. buffer_name(buf) .. ": " .. err
            end
        end
    end

    return true
end

function M.prepare_load(callback)
    local buffers = session_load_buffers()
    local blockers = session_load_blockers(buffers)

    if #blockers == 0 then
        local ok, err = clear_session_load_buffers(buffers, false)

        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        callback()
        return
    end

    vim.ui.input({
        prompt = table.concat(blockers, " | ")
            .. " | Type Q to force session switch, anything else cancels: ",
    }, function(answer)
        if answer ~= "Q" then
            vim.notify("Session switch cancelled.", vim.log.levels.INFO)
            return
        end

        local ok, err = clear_session_load_buffers(buffers, true)

        if not ok then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        callback()
    end)
end

return M
