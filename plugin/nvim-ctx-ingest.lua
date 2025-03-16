if vim.g.loaded_ctx_ingest == 1 then
  return
end
vim.g.loaded_ctx_ingest = 1

-- Check for required dependency
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
if not has_devicons then
  vim.notify("nvim-web-devicons is required for ctx-ingest", vim.log.levels.ERROR)
  return
end

-- Create highlights
vim.api.nvim_set_hl(0, "CtxIngestIgnored", { link = "Comment" })
vim.api.nvim_set_hl(0, "CtxIngestHeader", { link = "Title" })
vim.api.nvim_set_hl(0, "CtxIngestDirectory", { link = "Directory" })
vim.api.nvim_set_hl(0, "CtxIngestFile", { link = "Normal" })
vim.api.nvim_set_hl(0, "CtxIngestSelected", { link = "Visual" })
vim.api.nvim_set_hl(0, "CtxIngestColumnHeader", { link = "Comment" })
vim.api.nvim_set_hl(0, "CtxIngestSize", { link = "Number" })
vim.api.nvim_set_hl(0, "CtxIngestDate", { link = "Comment" })
vim.api.nvim_set_hl(0, "CtxIngestType", { link = "Type" })

vim.api.nvim_create_user_command('CtxIngest', function()
  require('nvim-ctx-ingest').open()
end, {})


