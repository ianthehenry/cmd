  $ source $TESTDIR/scaffold

Multiple errors:

  $ use <<EOF
  > (cmd/def
  >   --arg :number
  >   --bar :number)
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
  $ run --arg foo
  ! --bar: missing required argument
  ! --arg: foo is not a number
  [1]
