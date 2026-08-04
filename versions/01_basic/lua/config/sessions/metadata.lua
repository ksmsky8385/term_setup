local paths = require("config.sessions.paths")

local M = {}

function M.read(slot)
    local path = paths.metadata_path(slot)

    if vim.fn.filereadable(path) == 0 then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))

    if not ok or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

function M.write(slot, metadata)
    vim.fn.mkdir(paths.dir, "p")
    vim.fn.writefile({
        vim.json.encode(metadata),
    }, paths.metadata_path(slot))
end

return M
