return {
  "nvim-lua/plenary.nvim",

  {
    "nvchad/base46",
    build = function()
      require("base46").load_all_highlights()
    end,
  },

  {
    "nvchad/ui",
    lazy = false,
    config = function()
      require "nvchad"
    end,
  },

  "nvzone/volt",
  "nvzone/menu",
  { "nvzone/minty", cmd = { "Huefy", "Shades" } },

  {
    "nvim-tree/nvim-web-devicons",
    opts = function()
      dofile(vim.g.base46_cache .. "devicons")
      return { override = require "nvchad.icons.devicons" }
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    event = "User FilePost",
    opts = {
      indent = { char = "│", highlight = "IblChar" },
      scope = { char = "│", highlight = "IblScopeChar" },
    },
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "blankline")

      local hooks = require "ibl.hooks"
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
      require("ibl").setup(opts)

      dofile(vim.g.base46_cache .. "blankline")
    end,
  },

  -- file managing , picker etc
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    opts = function()
      return require "nvchad.configs.nvimtree"
    end,
  },

  {
    "folke/which-key.nvim",
    keys = { "<leader>", "<c-w>", '"', "'", "`", "c", "v", "g" },
    cmd = "WhichKey",
    opts = function()
      dofile(vim.g.base46_cache .. "whichkey")
      return {}
    end,
  },

  -- formatting!
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { lua = { "stylua" } },
    },
  },

  -- git stuff
  {
    "lewis6991/gitsigns.nvim",
    event = "User FilePost",
    opts = function()
      return require "nvchad.configs.gitsigns"
    end,
  },

  -- lsp stuff
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = function()
      local mason_opts = require("nvchad.configs.mason")
      mason_opts.ensure_installed = vim.tbl_extend("force", mason_opts.ensure_installed or {}, {
        "clangd",
        "clang-format",
        "codelldb",
        "black",
        "pyright",
        "ruff",
      })

      return mason_opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  -- load luasnips + cmp related in insert mode only
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      {
        -- snippet plugin
        "L3MON4D3/LuaSnip",
        dependencies = "rafamadriz/friendly-snippets",
        opts = { history = true, updateevents = "TextChanged,TextChangedI" },
        config = function(_, opts)
          require("luasnip").config.set_config(opts)
          require "nvchad.configs.luasnip"
        end,
      },

      -- autopairing of (){}[] etc
      {
        "windwp/nvim-autopairs",
        opts = {
          fast_wrap = {},
          disable_filetype = { "TelescopePrompt", "vim" },
        },
        config = function(_, opts)
          require("nvim-autopairs").setup(opts)

          -- setup cmp for autopairs
          local cmp_autopairs = require "nvim-autopairs.completion.cmp"
          require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
      },

      -- cmp sources plugins
      {
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
      },
    },
    opts = function()
      return require "nvchad.configs.cmp"
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = "Telescope",
    opts = function()
      return require "nvchad.configs.telescope"
    end,
  },
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    opts = {
      experimental = {check_rtp = false},
      preview = {
        filetypes = { "markdown", "codecompanion" },
        ignore_buftypes = {},
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
    build = ":TSUpdate",
    opts = function()
      local treesitter_opts = require("nvchad.configs.treesitter")
      treesitter_opts.ensure_installed = vim.tbl_extend("force", treesitter_opts.ensure_installed or {}, {
        "vim", "lua", "vimdoc",
        "html", "css", "markdown", "markdown_inline"
      })
      treesitter_opts.highlight = vim.tbl_extend("force", treesitter_opts.highlight or {}, { enable = true })

      return treesitter_opts
    end,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
    dependencies = {
       "OXY2DEV/markview.nvim",
    }
  },
  -- my stuff
  {
    "olimorris/codecompanion.nvim",
    lazy = false,
    opts = {
      strategies = {
        chat = {
          -- adapter = {
          --   name = "ollama",
          --   model = "devstral",
          -- },
          adapter = {
            name = "copilot",
            -- model = "claude-sonnet-4",
            model = "gpt-4.1",
          },
        },
        inline = {
          adapter = "copilot",
          -- adapter = {
          --   name = "ollama",
          --   model = "devstral",
          -- },
          keymaps = {
            accept_change = {
              modes = { n = "ga" },
              description = "Accept the suggested change",
            },
            reject_change = {
              modes = { n = "gr" },
              description = "Reject the suggested change",
            },
          },
        },
        cmd = {
          adapter = "copilot",
          -- adapter = {
          --   name = "ollama",
          --   model = "devstral",
          -- },
        },
      },
      display = {
        diff = {
          enabled = true,
          close_chat_at = 240,    -- Close an open chat buffer if the total columns of your display are less than...
          layout = "vertical",    -- vertical|horizontal split for default provider
          opts = { "internal", "filler", "closeoff", "algorithm:patience", "followwrap", "linematch:120" },
          provider = "mini_diff", -- default|mini_diff
        },
      },
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    cond = function() return vim.fn.executable("node") == 1 end,
    lazy = true,
    cmd = "Copilot suggestion",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        auto_refresh = true,
        suggestion = { enabled = true, auto_trigger = true }
      })
      -- Example: Accept Copilot suggestion with <C-l>
      vim.keymap.set("i", "<M-l>", function()
        require("copilot.suggestion").accept()
      end, { desc = "Accept Copilot suggestion" })
      vim.keymap.set("i", "<M-k>", function()
        require("copilot.suggestion").accept_word()
      end, { desc = "Accept Copilot suggested word" })
      vim.keymap.set("i", "<M-]>", function()
        require("copilot.suggestion").next()
      end, { desc = "next suggestion" })
    end,
  },
  -- mini diff
  {
    "echasnovski/mini.diff",
    event = "User FilePost",
    opts = {
      symbols = { added = "+", modified = "~", removed = "-" },
      highlight = { groups = { added = "DiffAdd", modified = "DiffChange", removed = "DiffDelete" } },
      diff_algorithm = "patience",
    },
    config = function(_, opts)
      require("mini.diff").setup(opts)
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
      { "<leader>gl", "<cmd>LazyGit<cr>", desc = "LazyGit" }
    }
  },
}
