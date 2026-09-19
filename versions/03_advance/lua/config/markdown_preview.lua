local M = {}

function M.patch_routes(plugin)
    local path = plugin.dir .. "/app/routes.js"
    if vim.fn.filereadable(path) ~= 1 then
        return
    end
    local lines = vim.fn.readfile(path)
    local marker = "// Redirect shortened preview URLs before the client parses the buffer number."
    if vim.tbl_contains(lines, marker) then
        return
    end
    for i, line in ipairs(lines) do
        if line == "// /page/:number" then
            local patch = {
                marker,
                "use((req, res, next) => {",
                "  const match = /^\\/(\\d+)\\/?$/.exec(req.asPath)",
                "  if (match) {",
                "    res.writeHead(302, { Location: `/page/${match[1]}` })",
                "    return res.end()",
                "  }",
                "  next()",
                "})",
                "",
            }
            for offset, value in ipairs(patch) do
                table.insert(lines, i + offset - 1, value)
            end
            vim.fn.writefile(lines, path)
            return
        end
    end
    vim.notify("Markdown preview: could not apply the refresh patch because the routes.js format has changed.", vim.log.levels.WARN)
end

function M.patch_server(plugin)
    local path = plugin.dir .. "/app/server.js"
    if vim.fn.filereadable(path) ~= 1 then
        return
    end
    local source = table.concat(vim.fn.readfile(path), "\n")
    local marker = "// Stop the preview server after the last client disconnects."
    if source:find(marker, 1, true) then
        return
    end
    local replacements = {
        { "  let clients = {}", [[  let clients = {}
  // Stop the preview server after the last client disconnects.
  let shutdownTimer
  const hasClients = () => Object.values(clients).some(cs => cs.some(c => c.connected))
  const cancelShutdown = () => {
    clearTimeout(shutdownTimer)
    shutdownTimer = undefined
  }
  const scheduleShutdown = () => {
    cancelShutdown()
    if (!hasClients()) {
      shutdownTimer = setTimeout(() => {
        if (!hasClients()) {
          logger.info('No preview clients for 10 seconds; stopping server')
          process.exit(0)
        }
      }, 10000)
    }
  }]] },
        { "    clients[bufnr].push(client)", "    clients[bufnr].push(client)\n    cancelShutdown()" },
        { [[    client.on('disconnect', function () {
      logger.info('disconnect: ', client.id)
      clients[bufnr] = (clients[bufnr] || []).map(c => c.id !== client.id)
      // update vim variable
      update_clients_active_var();
    })]], "" },
        { "    const buffers = await plugin.nvim.buffers", [[    client.on('disconnect', function () {
      logger.info('disconnect: ', client.id)
      clients[bufnr] = (clients[bufnr] || []).filter(c => c.id !== client.id)
      update_clients_active_var()
      scheduleShutdown()
    })

    const buffers = await plugin.nvim.buffers]] },
    }
    for _, replacement in ipairs(replacements) do
        local first, last = source:find(replacement[1], 1, true)
        if not first or source:find(replacement[1], last + 1, true) then
            vim.notify("Markdown preview: could not apply the shutdown patch because the server.js format has changed.", vim.log.levels.WARN)
            return
        end
        source = source:sub(1, first - 1) .. replacement[2] .. source:sub(last + 1)
    end
    vim.fn.writefile(vim.split(source, "\n", { plain = true }), path)
end

function M.build(plugin)
    local output = vim.fn.system({ "npm", "install", "--prefix", plugin.dir .. "/app" })
    if vim.v.shell_error ~= 0 then
        error(output)
    end
    M.patch_routes(plugin)
    M.patch_server(plugin)
end

function M.repair_on_start(plugin)
    M.patch_routes(plugin)
    M.patch_server(plugin)
    local app = plugin.dir .. "/app"
    -- Fresh installs already run Lazy's build hook. Repair existing copies only.
    if vim.fn.filereadable(app .. "/package.json") ~= 1 then
        return
    end
    local manifest = vim.json.decode(table.concat(vim.fn.readfile(app .. "/package.json"), "\n"))
    for name in pairs(manifest.dependencies or {}) do
        if vim.fn.isdirectory(app .. "/node_modules/" .. name) ~= 1 then
            vim.api.nvim_create_autocmd("VimEnter", {
                once = true,
                callback = function()
                    vim.schedule(function()
                        require("lazy").build({ plugins = { plugin.name } })
                    end)
                end,
            })
            return
        end
    end
end

return M
