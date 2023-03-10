  $ source $TESTDIR/scaffold

Parameters are required by default:

  $ use <<EOF
  > (cmd/def
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
  > (cmd/def
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
  > (cmd/def
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
  > (cmd/def "doc"
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
  > (cmd/def "doc"
  >   [renamed --arg] :string)
  > (pp renamed)
  > EOF

  $ run --arg foo
  "foo"

Aliases:

  $ use <<EOF
  > (cmd/def "doc"
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
  > (cmd/def "doc"
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
  > (cmd/def "doc"
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
  > (cmd/def "doc"
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
  2

Flag parameters:

  $ use <<EOF
  > (cmd/def "doc"
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
  > (cmd/def --arg :string)
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg hi
  "hi"

Duplicates allowed, take last:

  $ use <<EOF
  > (cmd/def "doc"
  >   --arg (last+ :string))
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

Listed, non-empty:

  $ use <<EOF
  > (cmd/def "doc"
  >   --arg (tuple+ :string))
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg
  ! --arg: no value for argument
  [1]
  $ run --arg foo
  ("foo")
  $ run --arg foo --arg bar
  ("foo" "bar")
  $ run --arg foo --arg
  ! --arg: no value for argument
  [1]
