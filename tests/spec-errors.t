  $ source $TESTDIR/scaffold

Missing type:

  $ use <<<'(cmd/immediate "doc" --arg)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) no type for --arg
  [1]

Duplicate type:

  $ use <<<'(cmd/immediate "doc" --arg :string :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple parsers specified for --arg (got :string, already have :string)
  [1]

Duplicate docstring:

  $ use <<<'(cmd/immediate "doc" --arg :string "help" "help")'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) docstring already set
  [1]

TODO: why doesn't this error?
Docstring before flag:

  $ use <<<'(cmd/immediate "doc" "help" --arg :string)'
  $ run_err
  ! --arg: missing required flag
  [1]

Exact duplicate flags:

  $ use <<<'(cmd/immediate "doc" --arg :string --arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple flags named --arg
  [1]

Different flags, same symbol:

  $ use <<<'(cmd/immediate "doc" --arg :string ---arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate flag arg
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string --foo :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate flag foo
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string [foo --bar] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate flag foo
  [1]

Illegal alias:

  $ use <<<'(cmd/immediate "doc" [--arg arg] hi)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) all aliases must start with - [--arg arg]
  [1]
  $ use <<<'(cmd/immediate "doc" [--arg "arg"] hi)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token [--arg "arg"]
  [1]
