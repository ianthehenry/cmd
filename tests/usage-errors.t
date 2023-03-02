  $ source $TESTDIR/scaffold

Multiple errors:

  $ use <<EOF
  > (cmd/script
  >   --arg :string
  >   --bar :string)
  > (pp arg)
  > EOF

  $ run
  ! --bar: missing required argument
  ! --arg: missing required argument
  [1]
  $ run --arg
  ! --bar: missing required argument
  ! --arg: no value for argument
  [1]
