local M = {}

local ts_utils = require('nvim-treesitter.ts_utils')
local query = require('vim.treesitter.query')

M.get_os = function(l)
  local os = vim.vim.loop.os_uname().sysname
  if os == "Linux" then
    return "xdg-open" .. vim.fn.shellescape(l)
  elseif os == "Macos" then
    return "open" .. vim.fn.shellescape(l)
  elseif os == "Windows" then
    return [[cmd.exe /c start "" ]] .. vim.fn.shellescape(l)
  else return l
  end
end

M.get_reference_link_destination = function(link_label)
  local language_tree = vim.treesitter.get_parser(0)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()
  local parse_query = vim.treesitter.parse_query('markdown', [[
  (link_reference_definition
    (link_label) @label (#eq? @label "]] .. link_label .. [[")
    (link_destination) @link_destination)
  ]])
  for _, captures, _ in parse_query:iter_matches(root, 0) do
    return query.get_node_text(captures[2], 0)
  end
end

M.get_link_destination = function()
  local node_at_cursor = ts_utils.get_node_at_cursor()
  local parent_node = node_at_cursor:parent()
  if not (node_at_cursor and parent_node) then
    return
  elseif node_at_cursor:type() == 'link_destination' then
    return vim.split(query.get_node_text(node_at_cursor, 0), '\n')[1]
  elseif node_at_cursor:type() == 'link_text' then
    local next_node = ts_utils.get_next_node(node_at_cursor)
    if next_node:type() == 'link_destination' then
      return vim.split(query.get_node_text(next_node, 0), '\n')[1]
    elseif next_node:type() == 'link_label' then
      local link_label = vim.split(query.get_node_text(next_node, 0), '\n')[1]
      return M.get_reference_link_destination(link_label)
    end
  elseif node_at_cursor:type() == 'link_reference_definition' or node_at_cursor:type() == 'inline_link' then
    local child_nodes = ts_utils.get_named_children(node_at_cursor)
    for _, node in pairs(child_nodes) do
	    if node:type() == 'link_destination' then
        return vim.split(query.get_node_text(node, 0), '\n')[1]
      end
    end
  elseif node_at_cursor:type() == 'full_reference_link' then
    local child_nodes = ts_utils.get_named_children(node_at_cursor)
    for _, node in pairs(child_nodes) do
	    if node:type() == 'link_label' then
        local link_label = vim.split(query.get_node_text(node, 0), '\n')[1]
        return M.get_reference_link_destination(link_label)
      end
    end
  elseif node_at_cursor:type() == 'link_label' then
    local link_label = vim.split(query.get_node_text(node_at_cursor, 0), '\n')[1]
    return M.get_reference_link_destination(link_label)
  else
    return
  end
end

M.resolve_link = function(link)
  local link_type
  if link:sub(1,1) == [[/]] then
    link_type = 'local'
    return link, link_type
  elseif link:sub(1,1) == [[~]] then
    link_type = 'local'
    return os.getenv("HOME") .. [[/]] .. link:sub(2), link_type
  elseif link:sub(1,8) == [[https://]] or link:sub(1,7) == [[http://]] then
    link_type = 'web'
    return link, link_type
  else
    link_type = 'local'
    return vim.fn.expand('%:p:h') .. [[/]] .. link, link_type
  end
end

M.follow_local_link = function(link)
  local fd = vim.loop.fs_open(link, "r", 438)
  if fd then
    local stat = vim.loop.fs_fstat(fd)
    if not stat or not stat.type == 'file' or not vim.loop.fs_access(link, 'R') then
      vim.loop.fs_close(fd)
    else
      vim.loop.fs_close(fd)
      vim.cmd(string.format('%s %s', 'e', vim.fn.vim.fn.meescape(link)))
    end
  end
end

M.follow_link = function()
  local link_destination = M.get_link_destination()

  if link_destination then
    local link, link_type = M.resolve_link(link_destination)
    if link_type == 'local' then
      M.follow_local_link(link)
    elseif link_type == 'web' then
      vim.fn.system(M.get_os(link))
    end
  end
end
