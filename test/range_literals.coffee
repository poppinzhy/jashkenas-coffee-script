# Range Literals
# --------------

# TODO: add indexing and method invocation tests: [1..4][0] is 1, [0...3].toString()

# shared array
shared = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

test "basic inclusive ranges", ->
  arrayEq [1, 2, 3] , [1..3]
  arrayEq [0, 1, 2] , [0..2]
  arrayEq [0, 1]    , [0..1]
  arrayEq [0]       , [0..0]
  arrayEq [-1]      , [-1..-1]
  arrayEq [-1, 0]   , [-1..0]
  arrayEq [-1, 0, 1], [-1..1]

test "basic exclusive ranges", ->
  arrayEq [1, 2, 3] , [1...4]
  arrayEq [0, 1, 2] , [0...3]
  arrayEq [0, 1]    , [0...2]
  arrayEq [0]       , [0...1]
  arrayEq [-1]      , [-1...0]
  arrayEq [-1, 0]   , [-1...1]
  arrayEq [-1, 0, 1], [-1...2]

  arrayEq [], [1...1]
  arrayEq [], [0...0]
  arrayEq [], [-1...-1]

test "downward ranges", ->
  arrayEq shared, [9..0].reverse()
  arrayEq [5, 4, 3, 2] , [5..2]
  arrayEq [2, 1, 0, -1], [2..-1]

  arrayEq [3, 2, 1]  , [3..1]
  arrayEq [2, 1, 0]  , [2..0]
  arrayEq [1, 0]     , [1..0]
  arrayEq [0]        , [0..0]
  arrayEq [-1]       , [-1..-1]
  arrayEq [0, -1]    , [0..-1]
  arrayEq [1, 0, -1] , [1..-1]
  arrayEq [0, -1, -2], [0..-2]

  arrayEq [4, 3, 2], [4...1]
  arrayEq [3, 2, 1], [3...0]
  arrayEq [2, 1]   , [2...0]
  arrayEq [1]      , [1...0]
  arrayEq []       , [0...0]
  arrayEq []       , [-1...-1]
  arrayEq [0]      , [0...-1]
  arrayEq [0, -1]  , [0...-2]
  arrayEq [1, 0]   , [1...-1]
  arrayEq [2, 1, 0], [2...-1]

test "ranges with variables as enpoints", ->
  [a, b] = [1, 3]
  arrayEq [1, 2, 3], [a..b]
  arrayEq [1, 2]   , [a...b]
  b = -2
  arrayEq [1, 0, -1, -2], [a..b]
  arrayEq [1, 0, -1]    , [a...b]

test "ranges with expressions as endpoints", ->
  [a, b] = [1, 3]
  arrayEq [2, 3, 4, 5, 6], [(a+1)..2*b]
  arrayEq [2, 3, 4, 5]   , [(a+1)...2*b]

test "large ranges are generated with looping constructs", ->
  down = [99..0]
  eq 100, (len = down.length)
  eq   0, down[len - 1]

  up = [0...100]
  eq 100, (len = up.length)
  eq  99, up[len - 1]

test "#1014 slices with arguments object", ->
  useArg0AtEnd = ->
    ary = -> [0..arguments[0]]
    ary 9
  arg0End = useArg0AtEnd()

  useArg0AtStart = ->
    ary = -> [arguments[0]..9]
    ary 0
  arg0Start = useArg0AtStart()

  useArgs0And1 = ->
    ary = -> [arguments[0]..arguments[1]]
    ary 0,9
  args0And1 = useArgs0And1()

  useArg0FromOuter = ->
    ary = -> [arguments[0]..9]
    ary(arguments[0])
  arg0FromOuter = useArg0FromOuter(0)

  arrayEq arg0End       , shared
  arrayEq arg0Start     , shared
  arrayEq args0And1     , shared
  arrayEq arg0FromOuter , shared
