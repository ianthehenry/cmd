  $ source $TESTDIR/scaffold

Quasiquote creates an automatic PEG parser:

  $ use <<EOF
  > (def a "a")
  > (cmd/script "doc"
  >   --arg ~(<- (* ,a "b")))
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg ab
  "ab"
  $ run --arg abc
  "ab"
  $ run --arg ba
  ! --arg: unable to parse "ba"
  [1]

Arbitrary functions:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg (required (fn [x] (string/ascii-upper x))))
  > (pp arg)
  > EOF
  $ run --arg hello
  "HELLO"

Number:

  $ use <<EOF
  > (cmd/script "doc"
  >   --arg :number)
  > (pp arg)
  > EOF
  $ run --arg 123
  123
  $ run --arg 123x
  ! --arg: 123x is not a number
  [1]
