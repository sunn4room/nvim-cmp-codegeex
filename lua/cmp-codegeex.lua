local M = {}

local apikey_dirs = {
  vim.fn.stdpath("state"),
  vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config",
  vim.env.HOME,
}

local ai_tri_chars = {}
for i = 32, 126 do
  ai_tri_chars[#ai_tri_chars + 1] = string.char(i)
end
ai_tri_chars[#ai_tri_chars + 1] = ""
ai_tri_chars[#ai_tri_chars + 1] = " "
ai_tri_chars[#ai_tri_chars + 1] = "\t"

M.setup = function(opts)
  local source = {}
  local timer = nil
  local process = nil

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

  function source:get_trigger_characters()
    return ai_tri_chars
  end

  function source:get_position_encoding_kind()
    return 'utf-8'
  end

  function source:complete(request, callback)
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    if process then
      process:kill()
      process = nil
    end

    local prompt = string.sub(request.context.cursor_before_line, request.offset)
    local path = vim.fn.expand "%"
    local language = vim.api.nvim_buf_get_option(0, "filetype")
    local cursor = { request.context.cursor.row-1, request.context.cursor.col-1 }
    local range = {
      math.max(0, cursor[1] - (opts.range or 100)),
      math.min(vim.fn.line "$" - 1, cursor[1] + (opts.range or 100)),
    }
    local prefix = table.concat(vim.api.nvim_buf_get_text(0, range[1], 0, cursor[1], cursor[2], {}), "\n")
    local suffix = table.concat(vim.api.nvim_buf_get_text(0, cursor[1], cursor[2], range[2], -1, {}), "\n")

    callback {
      isIncomplete = true,
      items = {
        {
          label = prompt .. "~",
          insertText = prompt,
          cmp = {
            kind_text = "CodeGeeX",
            kind_hl_group = "CmpItemKindCodeGeeX",
          },
        },
      },
    }

    local start_curl = vim.schedule_wrap(function()
      callback {
        isIncomplete = true,
        items = {
          {
            label = prompt .. "~~",
            insertText = prompt,
            cmp = {
              kind_text = "CodeGeeX",
              kind_hl_group = "CmpItemKindCodeGeeX",
            },
          },
        },
      }
      process = vim.system(
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
          process = nil
          local items = {}
          if result.code == 0 and result.signal == 0 then
            for _, choice in ipairs(vim.fn.json_decode(result.stdout).choices) do
              local content = choice.message.content
              local before = request.context.cursor_before_line
              local after = request.context.cursor_after_line
              if after == "" and content:sub(-1) == "\n" then
                content = content:sub(1, -2)
              end
              table.insert(items, {
                label = prompt .. content,
                documentation = {
                  kind = "plaintext",
                  value = table.concat({
                    "--- begin ---",
                    before .. content .. after,
                    "--- end ---",
                  }, "\n"),
                },
                cmp = {
                  kind_text = "CodeGeeX",
                  kind_hl_group = "CmpItemKindCodeGeeX",
                },
              })
            end
          end
          callback {
            isIncomplete = true,
            items = items,
          }
        end)
      )
    end)

    if opts.delay then
      timer = vim.uv.new_timer()
      timer:start(opts.delay, 0, function()
        timer:stop()
        timer:close()
        timer = nil
        start_curl()
      end)
    else
      start_curl()
    end
  end

  require("cmp").register_source("codegeex", source)
end

return M
