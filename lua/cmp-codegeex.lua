local M = {}

M.setup = function(opts)
  local source = {
    interrupt = function() end,
    timer = vim.uv.new_timer(),
  }

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
    self.interrupt()
    self.timer:start(opts.delay or 500, 0, vim.schedule_wrap(function()
      local prompt = string.sub(request.context.cursor_before_line, request.offset)
      local path = vim.fn.expand "%"
      local language = vim.api.nvim_get_option_value("filetype", { buf = 0 })
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
            items = {
              {
                label = prompt .. " " .. spinner_frames[spinner],
                insertText = prompt,
                filterText = prompt,
                cmp = {
                  kind_text = "CodeGeeX",
                  kind_hl_group = "CmpItemKindCodeGeeX",
                },
              },
            },
          }
          vim.defer_fn(function() update_spinner() end, 100)
        end
      end
      update_spinner()

      local killed = false
      local process = vim.system(
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
          if killed then return end
          spinner = 0
          if result.code == 0 then
            local response = vim.fn.json_decode(result.stdout)
            if response.error then
              vim.notify(response.error.message, 3, { title = "CodeGeeX" })
              callback()
            else
              local choice = response.choices[1]
              local content = choice.message.content
              local before = request.context.cursor_before_line
              local after = request.context.cursor_after_line
              if after == "" and content:sub(-1) == "\n" then
                content = content:sub(1, -2)
              end
              callback {
                isIncomplete = true,
                items = {
                  {
                    label = prompt .. "…",
                    insertText = prompt .. content,
                    documentation = {
                      kind = "markdown",
                      value = "```txt\n" .. before .. content .. after .. "\n```",
                    },
                    cmp = {
                      kind_text = "CodeGeeX",
                      kind_hl_group = "CmpItemKindCodeGeeX",
                    },
                  },
                },
              }
            end
          else
            vim.notify("Request failed: " .. result.stderr, 3, { title = "CodeGeeX" })
            callback()
          end
          self.interrupt = function() end
        end)
      )
      self.interrupt = function()
        process:kill(15)
        killed = true
        spinner = 0
        callback { isIncomplete = true, items = {} }
      end
    end))
    self.interrupt = function()
      self.timer:stop()
      callback { isIncomplete = true, items = {} }
    end
  end

  require("cmp").register_source("codegeex", source)
end

return M
