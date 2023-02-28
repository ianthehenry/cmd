  $ source $TESTDIR/scaffold

No docstring:

  $ use <<EOF
  > (cmd/script --arg :string)
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"

Docstring:

  $ use <<EOF
  > (cmd/script "doc" --arg :string)
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"

Param docstring:

  $ use <<EOF
  > (cmd/script "doc" --arg :string "arg doc")
  > (pp arg)
  > EOF
  $ run --arg hi
  "hi"
