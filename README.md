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
  },
}
```

Codegeex source is not available by default. You should enable codegeex source with `vim.g.use_codegeex = true`.

| nvim-cmp item | value                 |
| ------------- | --------------------- |
| source        | `codegeex`            |
| kind          | `CodeGeeX`            |
| highlight     | `CmpItemKindCodeGeeX` |
