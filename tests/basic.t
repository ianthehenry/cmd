  $ source $TESTDIR/scaffold

Flags are required by default:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg :string)
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required flag
  [1]
  $ run --arg
  ! --arg: missing argument
  [1]
  $ run --arg foo
  "foo"

Renamed flags:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   [renamed --arg] :string)
  > (pp renamed)
  > EOF

  $ run --arg foo
  "foo"

Aliases:

  $ use <<EOF
  > (cmd/immediate "doc"
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
  ! --other: flag already set
  [1]

Listed parameters are specified with square brackets:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg [:string])
  > (pp arg)
  > EOF

  $ run
  ()
  $ run --arg
  ! --arg: missing argument
  [1]
  $ run --arg foo
  ("foo")
  $ run --arg foo --arg bar
  ("foo" "bar")

Listed array parameters are specified as an array:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg @[:string])
  > (pp arg)
  > EOF

  $ run
  @[]
  $ run --arg
  ! --arg: missing argument
  [1]
  $ run --arg foo
  @["foo"]
  $ run --arg foo --arg bar
  @["foo" "bar"]

Count parameters:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   -v (count))
  > (pp v)
  > EOF

  $ run
  0
  $ run -v
  1
  $ run -v -v foo
  2
  $ run -vv foo
  ! unknown flag -vv
  [1]

Flag parameters:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   -v (flag))
  > (pp v)
  > EOF

  $ run
  false
  $ run -v
  true
  $ run -v -v
  ! -v: flag already set
  [1]
