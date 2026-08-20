-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Root detection: prefer .git over the LSP's root_dir, so <leader>e (Snacks
-- explorer) always opens at the repo root instead of a subfolder that happens
-- to contain a pyproject.toml/setup.py the Python LSP latched onto.
-- Default LazyVim spec is { "lsp", { ".git", "lua" }, "cwd" }.
vim.g.root_spec = { { ".git", "lua" }, "lsp", "cwd" }
