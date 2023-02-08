local M = {}
local s = {}

local ok_cmp, cmp = pcall(require, 'cmp')
local ok_luasnip, luasnip = pcall(require, 'luasnip')
local select_opts = {behavior = 'select'}
local setup_complete = false

if ok_cmp then
  select_opts = {behavior = cmp.SelectBehavior.Select}
end

function M.apply(opts)
  if not ok_cmp then
    local msg = "[lsp-zero] Could not find nvim-cmp. Please install nvim-cmp or set the option `manage_nvim_cmp` to false."
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  opts = opts or {}

  if type(opts.select_behavior) == 'string' then
    select_opts = {behavior = opts.select_behavior}
  end

  local config = M.cmp_config()
  config.sources = M.sources()
  config.mapping = M.default_mappings()

  -- Apparently this can fail
  pcall(function()
    if vim.o.completeopt == 'menu,preview' then
      vim.opt.completeopt:append('menu')
      vim.opt.completeopt:append('menuone')
      vim.opt.completeopt:append('noselect')
    end
  end)

  if type(opts.sources) == 'table' then
    config.sources = opts.sources
  end

  if type(opts.mapping) == 'table' then
    config.mapping = opts.mapping
  end

  if type(opts.documentation) == 'table' then
    config.window.documentation = s.merge(
      config.window.documentation,
      opts.documentation
    )
  elseif opts.documentation == false then
    config.window.documentation = cmp.config.disable
  end

  if type(opts.completion) == 'table' then
    config.completion = s.merge(config.completion, opts.completion)
  end

  if type(opts.formatting) == 'table' then
    config.formatting = s.merge(config.formatting, opts.formatting)
  end

  if opts.preselect ~= nil then
    config.preselect = opts.preselect
  end

  setup_complete = true

  cmp.setup(config)
end

function M.sources()
  local result = {}
  local register = function(mod, value)
    local pattern = string.format('lua/%s*', mod)
    local path = vim.api.nvim_get_runtime_file(pattern, 0)

    if #path > 0 then
      table.insert(result, value)
    end
  end

  register('cmp_path', {name = 'path'})
  register('cmp_nvim_lsp', {name = 'nvim_lsp', keyword_length = 3})
  register('cmp_buffer', {name = 'buffer', keyword_length = 3})
  register('cmp_luasnip', {name = 'luasnip', keyword_length = 2})

  return result
end

function M.default_mappings()
  local result = {
    -- confirm selection
    ['<CR>'] = cmp.mapping.confirm({select = false}),
    ['<C-y>'] = cmp.mapping.confirm({select = false}),

    -- navigate items on the list
    ['<Up>'] = cmp.mapping.select_prev_item(select_opts),
    ['<Down>'] = cmp.mapping.select_next_item(select_opts),
    ['<C-p>'] = cmp.mapping.select_prev_item(select_opts),
    ['<C-n>'] = cmp.mapping.select_next_item(select_opts),

    -- scroll up and down in the completion documentation
    ['<C-f>'] = cmp.mapping.scroll_docs(5),
    ['<C-u>'] = cmp.mapping.scroll_docs(-5),

    -- toggle completion
    ['<C-e>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.abort()
      else
        cmp.complete()
      end
    end),

    -- when menu is visible, navigate to next item
    -- when line is empty, insert a tab character
    -- else, activate completion
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item(select_opts)
      elseif s.check_back_space() then
        fallback()
      else
        cmp.complete()
      end
    end, {'i', 's'}),

    -- when menu is visible, navigate to previous item on list
    -- else, revert to default behavior
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item(select_opts)
      else
        fallback()
      end
    end, {'i', 's'}),
  }

  if ok_luasnip then
    -- go to next placeholder in the snippet
    result['<C-d>'] = cmp.mapping(function(fallback)
      if luasnip.jumpable(1) then
        luasnip.jump(1)
      else
        fallback()
      end
    end, {'i', 's'})

    -- go to previous placeholder in the snippet
    result['<C-b>'] = cmp.mapping(function(fallback)
      if luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, {'i', 's'})
  end

  return result
end

M.cmp_config = function()
  local result = {
    preselect = cmp.PreselectMode.Item,
    completion = {
      completeopt = 'menu,menuone,noinsert'
    },
    window = {
      documentation = s.merge(
        cmp.config.window.bordered(),
        {
          max_height = 15,
          max_width = 60,
        }
      )
    },
    formatting = {
      fields = {'abbr', 'menu', 'kind'},
      format = function(entry, item)
        local short_name = {
          nvim_lsp = 'LSP',
          nvim_lua = 'nvim'
        }

        local menu_name = short_name[entry.source.name] or entry.source.name

        item.menu = string.format('[%s]', menu_name)
        return item
      end,
    }
  }

  if ok_luasnip then
    result.snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    }
  end

  return result
end

function M.extend_cmp(opts)
  if setup_complete then
    return false
  end

  local ok, cmp = pcall(require, 'cmp')
  if not ok then
    local msg = "[lsp-zero] Could not find 'cmp' module."
    vim.notify(msg, vim.log.levels.ERROR)
    return false
  end

  local defaults = {
    formatting = true,
    documentation = true,
    snippet = true,
  }

  setup_complete = true

  opts = vim.tbl_deep_extend('force', defaults, opts or {})
  local config = M.cmp_config()
  config.completion = nil
  config.preselect = nil

  if opts.formatting == false then
    config.formatting = nil
  end

  if opts.documentation == false then
    config.window.documentation = nil
  end

  if opts.snippet == false then
    config.snippet = nil
  end

  -- Apparently this can fail
  pcall(function()
    if vim.o.completeopt == 'menu,preview' then
      vim.opt.completeopt:append('menu')
      vim.opt.completeopt:append('menuone')
      vim.opt.completeopt:append('noselect')
    end
  end)

  cmp.setup(config)

  return true
end

function s.merge(a, b)
  return vim.tbl_deep_extend('force', {}, a, b)
end

function s.check_back_space()
  local col = vim.fn.col('.') - 1
  if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
    return true
  else
    return false
  end
end

return M

