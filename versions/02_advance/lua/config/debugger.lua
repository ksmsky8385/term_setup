local M = {}

M.state = {
    prompt_args = true,
}

function M.prompt_args_enabled()
    return M.state.prompt_args == true
end

function M.toggle_prompt_args()
    M.state.prompt_args = not M.state.prompt_args
    vim.notify(
        "Debugger args prompt "
            .. (M.state.prompt_args and "enabled" or "disabled")
    )
end

function M.prompt_args()
    if not M.prompt_args_enabled() then
        return {}
    end

    local input = vim.fn.input("Args: ")

    if input == "" then
        return {}
    end

    return vim.fn.split(input)
end

return M
