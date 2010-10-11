# Ensure that carriage returns don't break compilation on Windows.
CoffeeScript = require('./../lib/coffee-script')
Lexer = require('./../lib/lexer')

js = CoffeeScript.compile("one\r\ntwo", {wrap: off})

ok js is "one;\ntwo;"


global.resultArray = []
CoffeeScript.run("resultArray.push i for i of global", {wrap: off, globals: on, fileName: 'tests'})

ok 'setInterval' in global.resultArray

ok 'passed' is CoffeeScript.eval '"passed"', wrap: off, globals: on, fileName: 'tests'

#750
try
  CoffeeScript.nodes 'f(->'
  ok no
catch e
  eq e.message, 'unclosed CALL_START on line 1'
