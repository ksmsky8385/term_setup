local local_bin = vim.fn.expand("~/.local/bin")
vim.fn.mkdir(local_bin, "p")

if not string.find(vim.env.PATH, local_bin, 1, true) then
    vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end

local function ensure_rg()
    local rg_path = local_bin .. "/rg"

    if vim.fn.executable(rg_path) == 1 then
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
        "-L",
        url,
        "-o",
        tar_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 다운로드 실패: " .. curl_result, vim.log.levels.ERROR)
        return
    end

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

    local cp_result = vim.fn.system({
        "cp",
        extract_dir .. "/rg",
        rg_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 복사 실패: " .. cp_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.system({
        "chmod",
        "+x",
        rg_path,
    })

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

    if vim.fn.executable("lazygit") == 1 or vim.fn.executable(lazygit_path) == 1 then
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
        "-L",
        url,
        "-o",
        tar_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazygit 다운로드 실패: " .. curl_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.mkdir(extract_dir, "p")

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

    local cp_result = vim.fn.system({
        "cp",
        extract_dir .. "/lazygit",
        lazygit_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazygit 복사 실패: " .. cp_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.system({
        "chmod",
        "+x",
        lazygit_path,
    })

    vim.notify("lazygit 설치 완료: " .. lazygit_path)
end

ensure_lazygit()
