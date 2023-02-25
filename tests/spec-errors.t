  $ source $TESTDIR/scaffold

Missing type:

  $ use <<<'(cmd/immediate "doc" --arg)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) no handler for arg
  [1]

Duplicate type:

  $ use <<<'(cmd/immediate "doc" --arg :string :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple handlers specified for arg (got :string, already have :string)
  [1]

Duplicate docstring:

  $ use <<<'(cmd/immediate "doc" --arg :string "help" "help")'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) docstring already set
  [1]

Docstring before flag:

  $ use <<<'(cmd/immediate "doc" "help" --arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token "help"
  [1]

Exact duplicate flags:

  $ use <<<'(cmd/immediate "doc" --arg :string --arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple arguments with alias --arg
  [1]

Different flags, same symbol:

  $ use <<<'(cmd/immediate "doc" --arg :string ---arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate argument arg
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string --foo :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate argument foo
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string [foo --bar] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate argument foo
  [1]

Illegal alias:

  $ use <<<'(cmd/immediate "doc" [--arg arg] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) all aliases must start with - [--arg arg]
  [1]
  $ use <<<'(cmd/immediate "doc" [--arg "arg"] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token [--arg "arg"]
  [1]
  $ use <<<'(cmd/immediate "doc" [])'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token []
  [1]

Choice with named arg:

  $ use <<<'(cmd/immediate "doc" --something {--foo 1 --bar 2})'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) you must specify all aliases for something inside {}
  [1]

Choice with aliases:

  $ use <<<'(cmd/immediate "doc" [--a --b] {--foo 1 --bar 2})'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) you must specify all aliases for a inside {}
  [1]

Duplicate aliases in choice:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   choice (required {[--foo --foo] 1 --bar 2}))
  > (pp choice)
  > EOF

  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate alias --foo
  [1]
