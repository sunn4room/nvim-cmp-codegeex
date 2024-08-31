# nvim-cmp-codegeex

nvim-cmp source for CodeGeeX.

```lua
-- lazy.nvim spec
{
  "sunn4room/nvim-cmp-codegeex",
  opts = {
    apikey = "xxx", -- the api key of codegeex,
    range = 100, -- the range to current line, the content in this range will send to codegeex to complete
	delay = 500, -- debounce timeout. disabled if nil.
  },
}
```

> Some infos about nvim-cmp:
>
> -   source name is `codegeex`
> -   kind text is `CodeGeeX`
> -   highlight group is `CmpItemKindCodeGeeX`

> if you don't want to save apikey in nvim config, you can save the apikey to `codegeex-apikey` in follow directories:
>
> -   the state directory in neovim
> -   the xdg config home
> -   the user home
