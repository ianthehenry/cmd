  $ source $TESTDIR/scaffold

Default value for optional flags is nil:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg (optional :string))
  > (pp arg)
  > EOF

  $ run
  nil
  $ run --arg
  ! --arg: missing argument
  [1]
  $ run --arg foo
  "foo"

You can specify a custom default:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg (optional :string "foo"))
  > (pp arg)
  > EOF

  $ run
  "foo"
  $ run --arg
  ! --arg: missing argument
  [1]
  $ run --arg foo
  "foo"
