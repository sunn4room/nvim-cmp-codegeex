local M = {}

local apikey_dirs = {
  vim.fn.stdpath "state",
  vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config",
  vim.env.HOME,
}

M.setup = function(opts)
  local source = {}

  function source:is_available()
    if opts.apikey ~= nil then
      return true
    end
    for _, dir in ipairs(apikey_dirs) do
      local apikey_file = io.open(dir .. "/codegeex-apikey", "r")
      if apikey_file then
        local apikey = vim.fn.trim(apikey_file:read "*all")
        opts.apikey = apikey
        apikey_file:close()
        return true
      end
    end
    vim.notify("CodeGeeX need your apikey!", 3)
    return false
  end

  function source:get_debug_name()
    return "CodeGeeX"
  end

  function source:complete(request, callback)
    local prompt = string.sub(request.context.cursor_before_line, request.offset)
    local path = vim.fn.expand "%"
    local language = vim.api.nvim_buf_get_option(0, "filetype")
    local cursor = { request.context.cursor.line, request.context.cursor.character }
    local range = {
      math.max(0, cursor[1] - (opts.range or 100)),
      math.min(vim.fn.line "$" - 1, cursor[1] + (opts.range or 100)),
    }
    local prefix = table.concat(vim.api.nvim_buf_get_text(0, range[1], 0, cursor[1], cursor[2], {}), "\n")
    local suffix = table.concat(vim.api.nvim_buf_get_text(0, cursor[1], cursor[2], range[2], -1, {}), "\n")
    vim.system(
      {
        "curl",
        "--location",
        "https://open.bigmodel.cn/api/paas/v4/chat/completions",
        "--header",
        "Authorization: Bearer " .. opts.apikey,
        "--header",
        "Content-Type: application/json",
        "--data",
        vim.fn.json_encode {
          model = "codegeex-4",
          messages = {},
          extra = {
            target = {
              path = path,
              language = language,
              code_prefix = prefix,
              code_suffix = suffix,
            },
          },
        },
      },
      { text = true },
      vim.schedule_wrap(function(result)
        local items = {}
        if result.code == 0 then
          for _, choice in ipairs(vim.fn.json_decode(result.stdout).choices) do
            table.insert(items, {
              label = prompt .. choice.message.content,
              documentation = {
                kind = "plaintext",
                value = table.concat({
                  "--- begin ---\n",
                  request.context.cursor_before_line,
                  choice.message.content,
                  request.context.cursor_after_line,
                  "\n--- end ---",
                }, ""),
              },
              cmp = {
                kind_text = "CodeGeeX",
                kind_hl_group = "CmpItemKindCodeGeeX",
              },
            })
          end
        end
        callback(items)
      end)
    )
    callback {
      isIncomplete = true,
      items = {
        { label = prompt .. "...", insertText = prompt },
      },
    }
  end

  require "cmp".register_source("codegeex", source)
end

return M
