  $ source $TESTDIR/scaffold

Structs can be used as enums:

  $ use <<EOF
  > (cmd/def "doc"
  >   choice {--foo 1 --bar 2})
  > (pp choice)
  > EOF

  $ run
  ! --foo/--bar: missing required argument
  [1]
  $ run --foo
  1
  $ run --bar
  2
  $ run --foo --foo
  ! --foo: duplicate argument
  [1]
  $ run --foo --bar
  ! --bar: duplicate argument
  [1]

Tables can be used as enums with values:

  $ use <<EOF
  > (cmd/def "doc"
  >   choice @{--foo :string --bar :string})
  > (pp choice)
  > EOF

  $ run
  ! --bar/--foo: missing required argument
  [1]
  $ run --foo
  ! --bar/--foo: missing required argument
  ! --foo: no value for argument
  [1]
  $ run --foo hi
  (:foo "hi")
  $ run --bar bye
  (:bar "bye")
  $ run --foo hi --foo bye
  ! --foo: duplicate argument
  [1]
  $ run --foo hi --bar bye
  ! --bar: duplicate argument
  [1]

Variant tags:

  $ use <<EOF
  > (cmd/def "doc"
  >   choice @{--foo [:x :string] --bar [:y :string]})
  > (pp choice)
  > EOF

  $ run --foo hi
  (:x "hi")
  $ run --bar bye
  (:y "bye")

Dynamic tags:

  $ use <<EOF
  > (def x (+ 1 2))
  > (cmd/def "doc"
  >   choice @{--foo [x :string] --bar [:y :string]})
  > (pp choice)
  > EOF

  $ run --foo hi
  (3 "hi")

Aliases within structs:

  $ use <<EOF
  > (cmd/def "doc"
  >   choice (required {[--foo -f] 1 --bar 2}))
  > (pp choice)
  > EOF

  $ run
  ! --bar/--foo/-f: missing required argument
  [1]
  $ run --foo
  1
  $ run -f
  1

Toggle:

  $ use <<EOF
  > (cmd/def "doc"
  >   choice (last {--foo true --no-foo false} true))
  > (pp choice)
  > EOF

  $ run
  true
  $ run --no-foo
  false
  $ run --foo
  true
  $ run --foo --no-foo
  false
