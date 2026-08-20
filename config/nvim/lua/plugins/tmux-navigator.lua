return {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window/pane" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window/pane" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window/pane" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window/pane" },
    },
    init = function()
      -- LazyVim maps <C-h/j/k/l> by default; drop those so the plugin's win.
      vim.g.tmux_navigator_no_mappings = 1
      -- Don't jump out of nvim when a split is unsaved in the target direction.
      vim.g.tmux_navigator_disable_when_zoomed = 1
    end,
  },
}
