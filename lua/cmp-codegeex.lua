local M = {}

M.setup = function(opts)
  local source = { count = 0 }

  function source:is_available()
    if not vim.g.use_codegeex then
      return false
    end
    if opts.apikey ~= nil then
      return true
    end
    if opts.apikey_file ~= nil then
      local apikey_file = io.open(opts.apikey_file, "r")
      if apikey_file then
        opts.apikey = vim.fn.trim(apikey_file:read("*all"))
        apikey_file:close()
        return true
      end
    end
    vim.notify("Apikey not found!", 3)
    return false
  end

  function source:get_trigger_characters()
    return { "", " ", "\t" }
  end

  function source:get_position_encoding_kind()
    return "utf-8"
  end

  function source:complete(request, callback)
    self.count = self.count + 1
    local id = self.count

    vim.defer_fn(function()
      if id ~= self.count then
        callback()
        return
      end

      local prompt = string.sub(request.context.cursor_before_line, request.offset)
      local path = vim.fn.expand "%"
      local language = vim.api.nvim_buf_get_option(0, "filetype")
      local cursor = { request.context.cursor.row - 1, request.context.cursor.col - 1 }
      local range = {
        math.max(0, cursor[1] - (opts.range or 500)),
        math.min(vim.fn.line("$") - 1, cursor[1] + (opts.range or 500)),
      }
      local prefix = table.concat(vim.api.nvim_buf_get_text(0, range[1], 0, cursor[1], cursor[2], {}), "\n")
      local suffix = table.concat(vim.api.nvim_buf_get_text(0, cursor[1], cursor[2], range[2], -1, {}), "\n")

      local spinner_frames = { "/", "-", "\\", "|" }
      local spinner = #spinner_frames
      local function update_spinner()
        if spinner ~= 0 then
          spinner = spinner == #spinner_frames and 1 or spinner + 1
          callback {
            isIncomplete = true,
            items = {{
              label = prompt .. " " .. spinner_frames[spinner],
              insertText = prompt,
              filterText = prompt,
              cmp = {
                kind_text = "CodeGeeX",
                kind_hl_group = "CmpItemKindCodeGeeX",
              },
            }},
          }
          vim.defer_fn(function() update_spinner() end, 100)
        end
      end
      update_spinner()

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
          spinner = 0
          if id ~= self.count then
            callback()
            return
          end

          if result.code == 0 and result.signal == 0 then
            local result_obj = vim.fn.json_decode(result.stdout)
            if result_obj.error then
              vim.notify(result_obj.error.message, 3, { title = "CodeGeeX" })
              callback()
            else
              local choice = result_obj.choices[1]
              local content = choice.message.content
              local first_cr = string.find(content .. "\n", "\n")
              local first = string.sub(content, 1, first_cr - 1)
              local before = request.context.cursor_before_line
              local after = request.context.cursor_after_line
              if after == "" and content:sub(-1) == "\n" then
                content = content:sub(1, -2)
              end
              callback {
                isIncomplete = true,
                items = {{
                  label = prompt .. first,
                  documentation = {
                    kind = "markdown",
                    value = "```txt\n" .. before .. content .. after .. "\n```",
                  },
                  cmp = {
                    kind_text = "CodeGeeX",
                    kind_hl_group = "CmpItemKindCodeGeeX",
                  },
                }},
              }
            end
          else
            vim.notify("curl run failed!", 3, { title = "CodeGeeX" })
            callback()
          end
        end)
      )
    end, opts.delay or 500)
  end

  require("cmp").register_source("codegeex", source)
end

return M
