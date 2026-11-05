local M = { idle_interval = 15000, generating_interval = 5000 }
local in_flight, last_started, cached, timer = false, nil, nil, nil

local function enabled()
    return require("config.sidebar_settings").get("agentic_usage")
end

local function sessions()
    local registry = package.loaded["agentic.session_registry"]
    return registry and registry.sessions or {}
end

local function supported(session)
    return not session._destroyed and session.session_id
        and (session.provider_name == "codex-acp" or session.provider_name == "pi-acp")
end

local function redraw_headers()
    for _, session in pairs(sessions()) do
        if session.widget then session.widget:schedule_header_refresh() end
    end
end

-- Read-only account query; no prompt is sent.
function M.query(callback)
    local job, done, pending = nil, false, ""
    local function finish(result, err)
        if done then return end
        done = true
        if job and job > 0 then pcall(vim.fn.jobstop, job) end
        callback(result, err)
    end
    local function send(message)
        vim.fn.chansend(job, vim.json.encode(message) .. "\n")
    end
    job = vim.fn.jobstart({ "codex", "app-server" }, {
        on_stdout = function(_, chunks)
            pending = pending .. table.concat(chunks, "\n")
            while not done do
                local eol = pending:find("\n", 1, true)
                if not eol then break end
                local line = pending:sub(1, eol - 1)
                pending = pending:sub(eol + 1)
                local ok, msg = pcall(vim.json.decode, line)
                if ok and type(msg) == "table" then
                    if msg.id == 1 then
                        if msg.error then finish(nil, "Initialization failed") break end
                        send({ method = "initialized" })
                        send({ id = 2, method = "account/rateLimits/read" })
                    elseif msg.id == 2 then
                        finish(msg.result, msg.error and "Request failed (check Codex login)")
                    end
                end
            end
        end,
        on_exit = function()
            finish(nil, "Connection closed (check Codex login)")
        end,
    })
    if job <= 0 then
        finish(nil, "codex executable not found")
        return
    end
    send({ id = 1, method = "initialize", params = {
        clientInfo = { name = "nvim_usage", version = "1.0.0" },
    } })
    vim.defer_fn(function() finish(nil, "Request timed out") end, 15000)
end

local function escape(text)
    return text:gsub("%%", "%%%%")
end

function M.header(_, state)
    if not enabled() or not state then return "" end
    local provider = state.get_provider_name and state:get_provider_name()
    local supported_provider = provider == "codex-acp" or provider == "pi-acp"
    -- SessionState stores provider_config.name (a display label), whereas
    -- SessionManager.provider_name stores the registry key.
    local config = package.loaded["agentic.config"]
    for _, key in ipairs({ "codex-acp", "pi-acp" }) do
        local entry = config and config.acp_providers and config.acp_providers[key]
        if entry and entry.name == provider then supported_provider = true end
    end
    if not supported_provider then return "" end
    local base = "%#AgenticUsageHeader#"
    if not cached then return base .. "Codex usage: loading..." end
    if cached.err then return base .. escape("Codex usage: " .. cached.err) end
    local result = cached.result
    local buckets = type(result) == "table" and result.rateLimitsByLimitId
    local limits = type(buckets) == "table" and buckets.codex
        or (type(result) == "table" and result.rateLimits)
    local parts = {}
    if type(limits) == "table" then
        for _, key in ipairs({ "primary", "secondary" }) do
            local window = limits[key]
            if type(window) == "table" and type(window.usedPercent) == "number" then
                local minutes = window.windowDurationMins
                local label = minutes == 300 and "5h" or minutes == 10080 and "Weekly"
                    or (type(minutes) == "number" and (minutes .. "min") or key)
                local remaining = math.max(0, math.min(100, 100 - window.usedPercent))
                local color = remaining <= 20 and "AgenticUsageCritical"
                    or remaining <= 50 and "AgenticUsageLow" or "AgenticUsageHeader"
                local reset = type(window.resetsAt) == "number"
                    and os.date(minutes == 300 and "%H:%M" or "%m/%d %H:%M", window.resetsAt)
                parts[#parts + 1] = label .. " %#" .. color .. "#"
                    .. string.format("%.0f%%%%", remaining) .. base
                    .. (reset and (" (" .. reset .. ")") or "")
            end
        end
    end
    return base .. (#parts > 0 and ("Left: " .. table.concat(parts, " | ")) or "Codex usage: unavailable")
end

function M.interval()
    if not enabled() then return nil end
    local visible = false
    for _, session in pairs(sessions()) do
        if supported(session) then
            if session.is_generating then return M.generating_interval end
            local widget = session.widget
            if widget and widget:get_visible_tab_id() == vim.api.nvim_get_current_tabpage() then
                visible = true
            end
        end
    end
    return visible and M.idle_interval or nil
end

-- One shared account query serves all sessions. Never overlap requests.
function M.tick(now, force)
    local interval = M.interval()
    if not interval then last_started = nil; return end
    if in_flight then return end
    now = now or vim.uv.now()
    if not force and last_started and now - last_started < interval then return end
    last_started, in_flight = now, true
    M.query(function(result, err)
        vim.schedule(function()
            in_flight = false
            cached = { result = result, err = err }
            redraw_headers()
        end)
    end)
end

function M.setup()
    if timer then return end
    timer = vim.uv.new_timer()
    -- A lightweight heartbeat handles visibility and generation transitions;
    -- network queries use the 15s / 5s intervals above.
    timer:start(1000, 1000, vim.schedule_wrap(function() M.tick() end))
    local group = vim.api.nvim_create_augroup("AgenticUsagePolling", { clear = true })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
        if timer then timer:stop(); timer:close(); timer = nil end
    end })
end

function M.refresh()
    redraw_headers()
    M.setup()
    M.tick(nil, true)
end

function M.toggle()
    local settings = require("config.sidebar_settings")
    settings.set("agentic_usage", not settings.get("agentic_usage"))
end

function M.on_visible()
    M.setup()
    vim.schedule(function() M.tick() end)
end

function M.on_open(data)
    if data.err or not data.session_id then return end
    M.setup()
    vim.schedule(function() M.tick(nil, true) end)
end

function M.on_submit()
    M.setup()
    -- is_generating is set immediately after the submit hook.
    vim.schedule(function() M.tick() end)
end

function M.on_complete()
    M.setup()
    M.tick(nil, true)
end

return M
