local local_bin = vim.fn.expand("~/.local/bin")

local function notify_error(message)
    vim.notify(message, vim.log.levels.ERROR)
end

local function executable(command)
    return vim.fn.executable(command) == 1
end

local function ensure_command(command, package_name)
    if executable(command) then
        return true
    end

    notify_error((package_name or command) .. " 설치에 필요한 명령을 찾지 못했습니다: " .. command)
    return false
end

local function ensure_dir(path, label)
    local ok, result = pcall(vim.fn.mkdir, path, "p")

    if ok and result ~= 0 then
        return true
    end

    notify_error((label or path) .. " 디렉터리를 만들 수 없습니다: " .. path)
    return false
end

local function path_contains(path)
    for entry in string.gmatch(vim.env.PATH or "", "[^:]+") do
        if entry == path then
            return true
        end
    end

    return false
end

ensure_dir(local_bin, "local bin")

if not path_contains(local_bin) then
    local path = vim.env.PATH or ""
    vim.env.PATH = path == "" and local_bin or (local_bin .. ":" .. path)
end

local function ensure_rg()
    local rg_path = local_bin .. "/rg"

    if executable("rg") or executable(rg_path) then
        return
    end

    if
        not ensure_dir(local_bin, "rg")
        or not ensure_command("curl", "rg")
        or not ensure_command("tar", "rg")
        or not ensure_command("cp", "rg")
        or not ensure_command("chmod", "rg")
    then
        return
    end

    vim.notify("rg가 없어서 ~/.local/bin에 자동 설치합니다.")

    local version = "14.1.1"
    local filename = "ripgrep-" .. version .. "-x86_64-unknown-linux-musl"
    local tar_path = "/tmp/" .. filename .. ".tar.gz"
    local extract_dir = "/tmp/" .. filename

    local url = "https://github.com/BurntSushi/ripgrep/releases/download/"
        .. version
        .. "/"
        .. filename
        .. ".tar.gz"

    local curl_result = vim.fn.system({
        "curl",
        "-fL",
        url,
        "-o",
        tar_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 다운로드 실패: " .. curl_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.delete(extract_dir, "rf")

    local tar_result = vim.fn.system({
        "tar",
        "-xzf",
        tar_path,
        "-C",
        "/tmp",
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 압축 해제 실패: " .. tar_result, vim.log.levels.ERROR)
        return
    end

    if vim.fn.filereadable(extract_dir .. "/rg") == 0 then
        notify_error("rg 압축 해제 결과 파일을 찾지 못했습니다: " .. extract_dir .. "/rg")
        return
    end

    local cp_result = vim.fn.system({
        "cp",
        extract_dir .. "/rg",
        rg_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 복사 실패: " .. cp_result, vim.log.levels.ERROR)
        return
    end

    local chmod_result = vim.fn.system({
        "chmod",
        "+x",
        rg_path,
    })

    if vim.v.shell_error ~= 0 then
        notify_error("rg 실행 권한 설정 실패: " .. chmod_result)
        return
    end

    if not executable(rg_path) then
        notify_error("rg 설치 후 실행 파일 확인 실패: " .. rg_path)
        return
    end

    vim.notify("rg 설치 완료: " .. rg_path)
end

ensure_rg()

local function latest_lazygit_download_url()
    local api_result = vim.fn.system({
        "curl",
        "-fsSL",
        "https://api.github.com/repos/jesseduffield/lazygit/releases/latest",
    })

    if vim.v.shell_error ~= 0 then
        return nil, "lazygit 최신 릴리즈 조회 실패: " .. api_result
    end

    local ok, release = pcall(vim.json.decode, api_result)

    if not ok or type(release) ~= "table" or type(release.assets) ~= "table" then
        return nil, "lazygit 릴리즈 응답 파싱 실패"
    end

    for _, asset in ipairs(release.assets) do
        local asset_name = type(asset) == "table"
            and type(asset.name) == "string"
            and asset.name:lower()
            or ""

        if
            type(asset) == "table"
            and type(asset.browser_download_url) == "string"
            and asset_name:match("linux_x86_64%.tar%.gz$")
        then
            return asset.browser_download_url
        end
    end

    return nil, "lazygit Linux x86_64 릴리즈 파일을 찾지 못했습니다."
end

local function ensure_lazygit()
    local lazygit_path = local_bin .. "/lazygit"

    if executable("lazygit") or executable(lazygit_path) then
        return
    end

    if
        not ensure_dir(local_bin, "lazygit")
        or not ensure_command("curl", "lazygit")
        or not ensure_command("tar", "lazygit")
        or not ensure_command("cp", "lazygit")
        or not ensure_command("chmod", "lazygit")
    then
        return
    end

    vim.notify("lazygit이 없어서 ~/.local/bin에 자동 설치합니다.")

    local url, url_error = latest_lazygit_download_url()

    if not url then
        vim.notify(url_error, vim.log.levels.ERROR)
        return
    end

    local filename = vim.fn.fnamemodify(url, ":t")
    local tar_path = "/tmp/" .. filename
    local extract_dir = "/tmp/lazygit-install"

    local curl_result = vim.fn.system({
        "curl",
        "-fL",
        url,
        "-o",
        tar_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazygit 다운로드 실패: " .. curl_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.delete(extract_dir, "rf")

    if not ensure_dir(extract_dir, "lazygit extract") then
        return
    end

    local tar_result = vim.fn.system({
        "tar",
        "-xzf",
        tar_path,
        "-C",
        extract_dir,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazygit 압축 해제 실패: " .. tar_result, vim.log.levels.ERROR)
        return
    end

    if vim.fn.filereadable(extract_dir .. "/lazygit") == 0 then
        notify_error("lazygit 압축 해제 결과 파일을 찾지 못했습니다: " .. extract_dir .. "/lazygit")
        return
    end

    local cp_result = vim.fn.system({
        "cp",
        extract_dir .. "/lazygit",
        lazygit_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazygit 복사 실패: " .. cp_result, vim.log.levels.ERROR)
        return
    end

    local chmod_result = vim.fn.system({
        "chmod",
        "+x",
        lazygit_path,
    })

    if vim.v.shell_error ~= 0 then
        notify_error("lazygit 실행 권한 설정 실패: " .. chmod_result)
        return
    end

    if not executable(lazygit_path) then
        notify_error("lazygit 설치 후 실행 파일 확인 실패: " .. lazygit_path)
        return
    end

    vim.notify("lazygit 설치 완료: " .. lazygit_path)
end

ensure_lazygit()
