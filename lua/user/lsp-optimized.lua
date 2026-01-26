-- Optimized LSP configuration with resource management
local M = {}

-- Auto-shutdown idle LSP servers after timeout
M.setup_lsp_timeout = function()
  local lsp_timeout_group = vim.api.nvim_create_augroup("LspTimeout", { clear = true })
  local idle_timers = {}
  
  -- Stop idle LSP clients after 5 minutes of inactivity
  local function stop_idle_client(client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    if client then
      vim.lsp.stop_client(client_id)
      vim.notify("Stopped idle LSP: " .. client.name, vim.log.levels.INFO)
    end
  end
  
  -- Reset timer on LSP activity
  local function reset_lsp_timer(client_id)
    if idle_timers[client_id] then
      vim.fn.timer_stop(idle_timers[client_id])
    end
    -- Set 5 minute timeout (300000ms)
    idle_timers[client_id] = vim.fn.timer_start(300000, function()
      stop_idle_client(client_id)
      idle_timers[client_id] = nil
    end)
  end
  
  -- Monitor LSP requests to reset idle timer
  vim.api.nvim_create_autocmd("LspRequest", {
    group = lsp_timeout_group,
    callback = function(args)
      local client_id = args.data.client_id
      if client_id then
        reset_lsp_timer(client_id)
      end
    end,
  })
  
  -- Start timer when LSP attaches
  vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_timeout_group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        reset_lsp_timer(args.data.client_id)
      end
    end,
  })
  
  -- Clean up timer when LSP detaches
  vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_timeout_group,
    callback = function(args)
      local client_id = args.data.client_id
      if idle_timers[client_id] then
        vim.fn.timer_stop(idle_timers[client_id])
        idle_timers[client_id] = nil
      end
    end,
  })
end

-- Optimized TypeScript LSP configuration
M.setup_typescript = function()
  local lspconfig = require('lspconfig')
  local capabilities = require('cmp_nvim_lsp').default_capabilities()
  
  -- Check if tsgo is available
  local tsgo_available = vim.fn.executable("npx") == 1 and 
                         vim.fn.system("npx tsgo --version 2>/dev/null"):match("Version") ~= nil
  
  if tsgo_available then
    -- Custom configuration for tsgo (Go-based TypeScript)
    -- Note: tsgo doesn't support --stdio flag, using standard ts_ls with memory optimizations instead
    vim.notify("tsgo found but using optimized ts_ls for better LSP compatibility", vim.log.levels.INFO)
  end
  
  -- Use standard ts_ls with heavy optimizations
  lspconfig.ts_ls.setup({
    capabilities = capabilities,
    cmd = { "typescript-language-server", "--stdio" },
      init_options = {
        hostInfo = "neovim",
        -- Use single tsserver instance
        preferences = {
          disableSuggestions = false,
          quotePreference = "auto",
          includeCompletionsForModuleExports = true,
          includeCompletionsWithInsertText = true,
          allowIncompleteCompletions = false,
        },
        -- Limit memory usage
        maxTsServerMemory = 2048,
        -- Disable automatic type acquisition
        disableAutomaticTypingAcquisition = true,
      },
      flags = {
        debounce_text_changes = 150,
      },
    settings = {
      typescript = {
        -- Force single tsserver process
        tsserver = {
          maxTsServerMemory = 2048,
          useSingleInferredProject = true,
          experimental = {
            enableProjectDiagnostics = false, -- Disable project-wide diagnostics
          },
        },
        inlayHints = {
          includeInlayParameterNameHints = 'all',
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = false, -- Reduce noise
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
      },
      javascript = {
        -- Force single tsserver process  
        tsserver = {
          maxTsServerMemory = 2048,
          useSingleInferredProject = true,
        },
        inlayHints = {
          includeInlayParameterNameHints = 'all',
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
      },
      completions = {
        completeFunctionCalls = true,
      },
    },
    flags = {
      debounce_text_changes = 150,
    },
    on_attach = function(client, bufnr)
      -- Disable document formatting (use prettier instead)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
      
      -- Log attachment with memory limit info
      vim.notify("TypeScript LSP attached (2GB mem limit, idle timeout: 5min)", vim.log.levels.INFO)
    end,
  })
end

-- Command to manually restart TypeScript LSP
M.restart_typescript_lsp = function()
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.name == "ts_ls" or client.name == "tsserver" then
      vim.lsp.stop_client(client.id)
      vim.notify("Restarting TypeScript LSP...", vim.log.levels.INFO)
      vim.defer_fn(function()
        vim.cmd("LspStart ts_ls")
      end, 100)
      return
    end
  end
  vim.notify("No TypeScript LSP running", vim.log.levels.WARN)
end

-- Command to show LSP memory usage
M.show_lsp_stats = function()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    vim.notify("No LSP clients running", vim.log.levels.INFO)
    return
  end
  
  local stats = {}
  for _, client in ipairs(clients) do
    table.insert(stats, string.format("%s (ID: %d)", client.name, client.id))
  end
  
  vim.notify("Active LSP Clients:\n" .. table.concat(stats, "\n"), vim.log.levels.INFO)
end

return M