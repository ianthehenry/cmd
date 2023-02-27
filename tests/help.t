  $ source $TESTDIR/scaffold

No docstring:

  $ use <<EOF
  > (cmd/immediate --arg :string)
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"

Docstring:

  $ use <<EOF
  > (cmd/immediate "doc" --arg :string)
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"

Param docstring:

  $ use <<EOF
  > (cmd/immediate "doc" --arg :string "arg doc")
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"
