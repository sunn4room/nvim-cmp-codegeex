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
ai_tri_chars[#ai_tri_chars + 1] = "\n"
ai_tri_chars[#ai_tri_chars + 1] = "\r"
ai_tri_chars[#ai_tri_chars + 1] = "\r\n"

M.setup = function(opts)
  local source = {}
  local count = 0

  function source:is_available()
    if not vim.b.use_codegeex then
      return false
    end
    if opts.apikey ~= nil then
      return true
    end
    local apikey_file = io.open(opts.apikey_file, "r")
    if apikey_file then
      opts.apikey = vim.fn.trim(apikey_file:read("*all"))
      apikey_file:close()
      return true
    end
    vim.notify("CodeGeeX need your apikey!", 3)
    return false
  end

  function source:get_trigger_characters()
    return ai_tri_chars
  end

  function source:get_position_encoding_kind()
    return "utf-8"
  end

  function source:complete(request, callback)
    count = count + 1
    local id = count
    vim.defer_fn(function()
      if id ~= count then
        callback(nil)
        return
      end

      local prompt = string.sub(request.context.cursor_before_line, request.offset)
      local path = vim.fn.expand "%"
      local language = vim.api.nvim_buf_get_option(0, "filetype")
      local cursor = { request.context.cursor.row - 1, request.context.cursor.col - 1 }
      local line_count = vim.fn.line("$")
      local range = {
        math.max(0, cursor[1] - (opts.range or line_count)),
        math.min(line_count - 1, cursor[1] + (opts.range or line_count)),
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
          if result.code == 0 and result.signal == 0 then
            local result_obj = vim.fn.json_decode(result.stdout)
            if result_obj.error then
              vim.notify(result_obj.error.message, 3, { title = "CodeGeeX" })
              callback(nil)
            else
              local choice = result_obj.choices[1]
              local content = choice.message.content
              local before = request.context.cursor_before_line
              local after = request.context.cursor_after_line
              if after == "" and content:sub(-1) == "\n" then
                content = content:sub(1, -2)
              end
              callback({{
                label = prompt .. "...",
                insertText = prompt .. content,
                documentation = {
                  kind = "markdown",
                  value = "```txt\n" .. before .. content .. after .. "\n```",
                },
                cmp = {
                  kind_text = "CodeGeeX",
                  kind_hl_group = "CmpItemKindCodeGeeX",
                },
              }})
            end
          else
            vim.notify("curl run failed!", 3, { title = "CodeGeeX" })
            callback(nil)
          end
        end)
      )
    end, opts.delay or 500)
  end

  require("cmp").register_source("codegeex", source)
end

return M
