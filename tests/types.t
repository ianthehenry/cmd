  $ source $TESTDIR/scaffold

Quasiquote creates an automatic PEG parser:

  $ use <<EOF
  > (def a "a")
  > (cmd/immediate "doc"
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
  > (cmd/immediate "doc"
  >   --arg (required (fn [x] (string/ascii-upper x))))
  > (pp arg)
  > EOF
  $ run --arg hello
  "HELLO"
