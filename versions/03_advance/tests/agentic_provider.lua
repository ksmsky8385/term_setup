-- XDG_STATE_HOME=/tmp/agentic-provider-test nvim --headless -u NONE -i NONE -l tests/agentic_provider.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/agentic.nvim")
local config = require("config.agentic_config")
local settings = require("config.sidebar_settings")
local options = require("agentic.acp.agent_config_options"):new({}, {})
-- pi-acp's configOptions format, including its model and thinking labels.
options:set_options({
    { id = "model", category = "model", type = "select", currentValue = "openai-codex/model-test",
        options = { { value = "openai-codex/model-test", name = "Test model" } } },
    { id = "thinking", category = "thought_level", type = "select", currentValue = "high",
        options = { { value = "high", name = "Thinking: high" } } },
})
local state = require("agentic.acp.session_state"):new(options, "pi-acp")
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)
local key = vim.api.nvim_get_current_tabpage() + 100
local session = { session_id = "pi-session", provider_name = "pi-acp",
    session_state = state, widget = { buf_nrs = { chat = buf } } }
package.loaded["agentic.session_registry"] = { sessions = { [key] = session } }
assert(config.state_for_window(win) == state, "session key must not be confused with tab ID")
assert(state:get_model_name() == "Test model")
assert(state:get_thought_level_name() == "Thinking: high")
config.remember_provider({ session_key = key, session_id = "pi-session" })
assert(require("agentic.config").provider == "pi-acp")
package.loaded["config.sidebar_settings"] = nil
settings = require("config.sidebar_settings")
assert(settings.get("agentic_provider") == "pi-acp", "restart must preserve provider in JSON")
assert(dofile("lua/plugins/agentic.lua").opts.provider == "pi-acp")
session.provider_name = "codex-acp"
config.remember_provider({ session_key = key, session_id = "pi-session", err = {} })
assert(settings.get("agentic_provider") == "pi-acp", "failed creation must not change preference")
-- Verify the actual statusline callback, rather than only the state getter.
local rendered
package.loaded["lualine"] = { setup = function(opts) rendered = opts end }
package.loaded["config.terminal"] = { is_status_terminal = function() return false end }
package.loaded["config.window_picker"] = { label_for_window = function() return "" end }
dofile("lua/plugins/lualine.lua").config()
vim.bo[buf].filetype = "AgenticChat"
local status = rendered.sections.lualine_c[1][1]()
assert(status == "Test model (high)", status)
options:set_options({
    { id = "model", category = "model", type = "select", currentValue = "next-model",
        options = { { value = "next-model", name = "Next model" } } },
    { id = "thinking", category = "thought_level", type = "select", currentValue = "low",
        options = { { value = "low", name = "Thinking: low" } } },
})
assert(rendered.inactive_sections.lualine_c[1][1]() == "Next model (low)")
print("agentic provider and statusline: PASS")
