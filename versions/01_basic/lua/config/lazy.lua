local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    if vim.fn.executable("git") ~= 1 then
        vim.notify("lazy.nvim 설치에 필요한 명령을 찾지 못했습니다: git", vim.log.levels.ERROR)
        return
    end

    local clone_result = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("lazy.nvim 설치 실패: " .. clone_result, vim.log.levels.ERROR)
        return
    end

    if not vim.loop.fs_stat(lazypath) then
        vim.notify("lazy.nvim 설치 후 경로 확인 실패: " .. lazypath, vim.log.levels.ERROR)
        return
    end
end

vim.opt.rtp:prepend(lazypath)

local ok, lazy = pcall(require, "lazy")

if not ok then
    vim.notify("lazy.nvim을 불러오지 못했습니다.", vim.log.levels.ERROR)
    return
end

lazy.setup({
    spec = {
        require("plugins.treesitter"),
        require("plugins.nvim-tree"),
        require("plugins.telescope"),
        require("plugins.dashboard"),
    },
})
