local M = {}

M.servers = {
    "pyright",
    "lua_ls",
    "bashls",
    "clangd",
    "jsonls",
    "yamlls",
    "taplo",
    "marksman",
    "vimls",
}

function M.configured()
    local servers = {}

    for _, server in ipairs(M.servers) do
        servers[server] = true
    end

    return servers
end

return M
