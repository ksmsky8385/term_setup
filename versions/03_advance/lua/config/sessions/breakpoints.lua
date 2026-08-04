local M = {}

local VERSION = 1

local function breakpoint_module()
    local ok, breakpoints = pcall(require, "dap.breakpoints")

    if not ok then
        return nil
    end

    return breakpoints
end

local function buffer_path(bufnr)
    if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    local name = vim.api.nvim_buf_get_name(bufnr)

    if name == "" then
        return nil
    end

    return vim.fn.fnamemodify(name, ":p")
end

local function usable_breakpoint(bp)
    return type(bp) == "table" and type(bp.line) == "number" and bp.line > 0
end

function M.snapshot()
    local breakpoints = breakpoint_module()

    if not breakpoints or type(breakpoints.get) ~= "function" then
        return {
            version = VERSION,
            files = {},
        }
    end

    local files = {}

    local ok, grouped = pcall(breakpoints.get)

    if not ok or type(grouped) ~= "table" then
        return {
            version = VERSION,
            files = {},
        }
    end

    for bufnr, items in pairs(grouped) do
        local path = buffer_path(bufnr)

        if path and type(items) == "table" then
            local saved = {}

            for _, bp in ipairs(items) do
                if usable_breakpoint(bp) then
                    table.insert(saved, {
                        line = bp.line,
                        condition = bp.condition,
                        hitCondition = bp.hitCondition,
                        logMessage = bp.logMessage,
                    })
                end
            end

            if #saved > 0 then
                table.insert(files, {
                    path = path,
                    breakpoints = saved,
                })
            end
        end
    end

    table.sort(files, function(left, right)
        return left.path < right.path
    end)

    return {
        version = VERSION,
        files = files,
    }
end

local function buffer_for_path(path)
    if type(path) ~= "string" or path == "" or vim.fn.filereadable(path) == 0 then
        return nil
    end

    local bufnr = vim.fn.bufadd(path)

    if type(bufnr) ~= "number" or bufnr <= 0 then
        return nil
    end

    pcall(vim.fn.bufload, bufnr)

    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    return bufnr
end

function M.restore(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    local breakpoints = breakpoint_module()

    if
        not breakpoints
        or type(breakpoints.clear) ~= "function"
        or type(breakpoints.set) ~= "function"
    then
        return
    end

    pcall(breakpoints.clear)

    for _, file in ipairs(snapshot.files or {}) do
        local bufnr = buffer_for_path(file.path)

        if bufnr then
            for _, bp in ipairs(file.breakpoints or {}) do
                if usable_breakpoint(bp) then
                    pcall(breakpoints.set, {
                        condition = bp.condition,
                        hit_condition = bp.hitCondition,
                        log_message = bp.logMessage,
                    }, bufnr, bp.line)
                end
            end
        end
    end
end

return M
