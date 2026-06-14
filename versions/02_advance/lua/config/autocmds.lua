local function set_indent(patterns, size, expandtab)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = patterns,
        callback = function()
            vim.opt_local.tabstop = size
            vim.opt_local.shiftwidth = size
            vim.opt_local.softtabstop = size
            vim.opt_local.expandtab = expandtab
        end,
    })
end

set_indent({
    "python",
    "java",
    "lua",
    "rust",
    "php",
    "cs",
    "vim",
}, 4, true)

set_indent({
    "json",
    "jsonc",
    "yaml",
    "toml",
    "markdown",
    "markdown_inline",
    "html",
    "css",
    "scss",
    "sass",
    "less",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "tsx",
    "vue",
    "svelte",
    "xml",
    "graphql",
}, 2, true)

set_indent({
    "sh",
    "bash",
    "zsh",
    "c",
    "cpp",
    "go",
    "make",
}, 4, false)
