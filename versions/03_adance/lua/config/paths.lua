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