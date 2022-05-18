

local Config = {
  enable = true,
  md_ext = false,
  ixi_ext = true,

  filetypes = {

  },
}

Config.setup = function(opts)
  if     vim.g.exi_enable == false then Config.md_ext = false
  elseif vim.g.exi_md_ext == true then Config.md_ext = true
  elseif vim.g.exi_md_ext == true then Config.ixi_ext = true
  else
  end
end

return Config
