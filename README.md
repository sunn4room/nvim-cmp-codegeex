# nvim-cmp-codegeex

> Require nvim-0.10 with new feature `vim.system`

nvim-cmp source for CodeGeeX.

```lua
-- lazy.nvim spec
{
  "sunn4room/nvim-cmp-codegeex",
  opts = {
    apikey = "xxx", -- the api key of codegeex.
    apikey_file = "/path/to/apikey/file", -- the api key file of codegeex.
    range = nil, -- the range to current line for completion context.
    delay = nil, -- debounce timeout. 500 is a good choice.
  },
}
```

For security reason, codegeex source is not available by default. You should enable codegeex source with `vim.b.use_codegeex = true`.

> nvim-cmp:
>
> -   source name is `codegeex`
> -   kind text is `CodeGeeX`
> -   highlight group is `CmpItemKindCodeGeeX`
