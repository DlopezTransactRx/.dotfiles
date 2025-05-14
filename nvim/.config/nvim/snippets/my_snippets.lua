local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s('hw', {
    t 'HelloWorld(',
    i(1, '"Hello, world!"'),
    t ')',
  }),
}
