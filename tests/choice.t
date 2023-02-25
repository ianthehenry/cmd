  $ source $TESTDIR/scaffold

Structs can be used as enums:

  $ use <<EOF
  > (cmd/immediate "doc"
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
  > (cmd/immediate "doc"
  >   choice @{--foo :string --bar :string})
  > (pp choice)
  > EOF

  $ run
  ! --bar/--foo: missing required argument
  [1]
  $ run --foo
  ! --foo: missing argument
  [1]
  $ run --foo hi
  "hi"
  $ run --bar bye
  "bye"
  $ run --foo hi --foo bye
  ! --foo: duplicate argument
  [1]
  $ run --foo hi --bar bye
  ! --bar: duplicate argument
  [1]

Aliases within structs:

  $ use <<EOF
  > (cmd/immediate "doc"
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
  > (cmd/immediate "doc"
  >   choice (last? {--foo true --no-foo false} true))
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
