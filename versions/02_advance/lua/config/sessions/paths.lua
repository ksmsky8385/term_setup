local M = {}

M.dir = vim.fn.stdpath("state") .. "/sessions"

function M.session_path(slot)
    return M.dir .. "/slot-" .. slot .. ".vim"
end

function M.metadata_path(slot)
    return M.dir .. "/slot-" .. slot .. ".json"
end

function M.slot_files(slot)
    return {
        M.session_path(slot),
        M.metadata_path(slot),
    }
end

return M
