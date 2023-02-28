  $ source $TESTDIR/scaffold

Parameters are required by default:

  $ use <<EOF
  > (cmd/script
  >   --arg :string)
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  "foo"

Default value for optional flags is nil:

  $ use <<EOF
  > (cmd/script
  >   --arg (optional :string))
  > (pp arg)
  > EOF

  $ run
  nil
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  "foo"

You can specify a custom default:

  $ use <<EOF
  > (cmd/script
  >   --arg (optional :string "foo"))
  > (pp arg)
  > EOF

  $ run
  "foo"
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  "foo"

Explicit required arguments:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg (required :string))
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  "foo"

Renamed flags:

  $ use <<EOF
  > (cmd/script "doc"
  >   [renamed --arg] :string)
  > (pp renamed)
  > EOF

  $ run --arg foo
  "foo"

Aliases:

  $ use <<EOF
  > (cmd/script "doc"
  >   [--arg -a --other] :string)
  > (pp arg)
  > EOF

  $ run --arg "foo"
  "foo"
  $ run -a foo
  "foo"
  $ run --other foo
  "foo"
  $ run --arg foo --other foo
  ! --other: duplicate argument
  [1]

Listed parameters, tuple:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg (tuple :string))
  > (pp arg)
  > EOF

  $ run
  ()
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  ("foo")
  $ run --arg foo --arg bar
  ("foo" "bar")

Listed array parameters, array:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg (array :string))
  > (pp arg)
  > EOF

  $ run
  @[]
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  @["foo"]
  $ run --arg foo --arg bar
  @["foo" "bar"]

Count parameters:

  $ use <<EOF
  > (cmd/script "doc"
  >   -v (counted))
  > (pp v)
  > EOF

  $ run
  0
  $ run -v
  1
  $ run -v -v
  2
  $ run -vv
  ! unknown parameter -vv
  [1]

Flag parameters:

  $ use <<EOF
  > (cmd/script "doc"
  >   -v (flag))
  > (pp v)
  > EOF

  $ run
  false
  $ run -v
  true
  $ run -v -v
  ! -v: duplicate argument
  [1]

Docstring is optional:

  $ use <<EOF
  > (cmd/script --arg :string)
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg hi
  "hi"

Duplicates allowed, take last:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg (last :string))
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  "foo"
  $ run --arg foo --arg bar
  "bar"
  $ run --arg foo --arg
  ! --arg: no value for argument
  [1]
