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

local function path_join(...)
    return table.concat({ ... }, "/")
end

local function executable(path)
    return path and path ~= "" and vim.fn.executable(path) == 1
end

local function python_from_root(root)
    if not root or root == "" then
        return nil
    end

    local candidates = {
        path_join(root, "bin", "python"),
        path_join(root, "Scripts", "python.exe"),
    }

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            return candidate
        end
    end

    return nil
end

local function root_from_env(env_name)
    local root = vim.env[env_name]

    if not root or root == "" then
        return nil
    end

    if python_from_root(root) then
        return root
    end

    return nil
end

local function venv_root_from_marker(marker)
    local found = vim.fs.find(marker, {
        path = vim.fn.getcwd(),
        upward = true,
        type = "directory",
        limit = 1,
    })[1]

    if found and python_from_root(found) then
        return found
    end

    return nil
end

local function venv_root_from_pyvenv_cfg()
    local configs = vim.fs.find("pyvenv.cfg", {
        path = vim.fn.getcwd(),
        upward = true,
        type = "file",
        limit = 1,
    })

    if configs[1] then
        local root = vim.fs.dirname(configs[1])

        if python_from_root(root) then
            return root
        end
    end

    return nil
end

local function venv_root_from_project_children()
    local cwd = vim.fn.getcwd()

    for _, entry in ipairs(vim.fn.globpath(cwd, "*", false, true)) do
        if vim.fn.isdirectory(entry) == 1 and vim.fn.filereadable(path_join(entry, "pyvenv.cfg")) == 1 then
            if python_from_root(entry) then
                return entry
            end
        end
    end

    return nil
end

function M.python_venv_root()
    for _, env_name in ipairs({ "VIRTUAL_ENV", "CONDA_PREFIX" }) do
        local root = root_from_env(env_name)

        if root then
            return root
        end
    end

    for _, marker in ipairs({ ".venv", "venv", "env" }) do
        local root = venv_root_from_marker(marker)

        if root then
            return root
        end
    end

    return venv_root_from_pyvenv_cfg() or venv_root_from_project_children()
end

local function system_python()
    local candidates = {
        vim.fn.exepath("python3"),
        vim.fn.exepath("python"),
    }

    for _, candidate in ipairs(candidates) do
        if candidate ~= "" then
            return candidate
        end
    end

    return "python"
end

local function env_executable(env_name, ...)
    local root = vim.env[env_name]

    if not root or root == "" then
        return nil
    end

    local candidate = path_join(root, ...)

    if executable(candidate) then
        return candidate
    end

    return nil
end

local function first_exepath(names)
    for _, name in ipairs(names) do
        local path = vim.fn.exepath(name)

        if path ~= "" then
            return path
        end
    end

    return nil
end

function M.java_executable()
    return env_executable("JAVA_HOME", "bin", "java")
        or first_exepath({ "java" })
        or "java"
end

function M.node_executable()
    return first_exepath({ "node" }) or "node"
end

function M.go_executable()
    return first_exepath({ "go" }) or "go"
end

function M.codelldb_executable()
    return first_exepath({ "codelldb" }) or "codelldb"
end

function M.python_executable()
    return python_from_root(M.python_venv_root())
        or system_python()
end

function M.python_environment()
    local root = M.python_venv_root()

    if not root then
        return nil
    end

    local bin = vim.fn.isdirectory(path_join(root, "bin")) == 1 and path_join(root, "bin")
        or path_join(root, "Scripts")
    local separator = vim.fn.has("win32") == 1 and ";" or ":"

    return {
        VIRTUAL_ENV = root,
        PATH = bin .. separator .. (vim.env.PATH or ""),
    }
end

function M.runtime_executable(filetype)
    local ft = filetype or vim.bo.filetype

    if ft == "python" then
        return "Python", M.python_executable()
    elseif ft == "java" then
        return "Java", M.java_executable()
    elseif
        ft == "javascript"
        or ft == "javascriptreact"
        or ft == "typescript"
        or ft == "typescriptreact"
    then
        return "Node", M.node_executable()
    elseif ft == "go" then
        return "Go", M.go_executable()
    elseif ft == "c" or ft == "cpp" or ft == "rust" then
        return "codelldb", M.codelldb_executable()
    end

    return "Runtime", "No runtime path rule for filetype: " .. (ft ~= "" and ft or "none")
end

return M
