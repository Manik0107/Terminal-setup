-- Point pyright at the right interpreter automatically, per project.
-- Mirrors what the VS Code Python extension does: find the project venv and
-- hand its interpreter to the language server, instead of falling back to the
-- system python (which has none of the project's packages installed).

--- Walk up from `startpath` looking for a virtualenv, and return its python.
--- @param startpath string
--- @return string
local function find_python(startpath)
  -- 1. An activated shell venv always wins (`source .venv/bin/activate`).
  if vim.env.VIRTUAL_ENV then
    local p = vim.env.VIRTUAL_ENV .. "/bin/python"
    if vim.uv.fs_stat(p) then
      return p
    end
  end

  -- 2. Otherwise search upward for a venv directory. Searching from the LSP
  --    root (not the file) still finds venvs *above* it, which matters for
  --    monorepos where each subproject has its own requirements.txt but the
  --    venv is shared at the repo root.
  local candidates = vim.fs.find({ ".venv", "venv", "env" }, {
    path = startpath,
    upward = true,
    type = "directory",
    limit = math.huge,
  })
  for _, dir in ipairs(candidates) do
    local p = dir .. "/bin/python"
    if vim.uv.fs_stat(p) then
      return p
    end
  end

  -- 3. Nothing project-local: fall back to PATH.
  local sys = vim.fn.exepath("python3")
  return sys ~= "" and sys or "python"
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          -- `before_init` (not lspconfig's `on_new_config`): LazyVim on nvim
          -- 0.12 configures servers via vim.lsp.config/enable, so lspconfig
          -- hooks never fire.
          before_init = function(params, config)
            local root = config.root_dir or params.rootPath or vim.fn.getcwd()
            local python = find_python(root)
            config.settings = config.settings or {}
            config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, {
              pythonPath = python,
              defaultInterpreterPath = python,
            })
          end,
        },
      },
    },
  },
}
