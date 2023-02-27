  $ source $TESTDIR/scaffold

Missing type:

  $ use <<<'(cmd/immediate --arg)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) no handler for arg
  [1]

Duplicate type:

  $ use <<<'(cmd/immediate --arg :string :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple handlers specified for arg (got :string, already have :string)
  [1]

Duplicate param docstring:

  $ use <<<'(cmd/immediate "doc" --arg :string "help" "help")'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) docstring already set
  [1]

Docstring before param:

  $ use <<<'(cmd/immediate "doc" "help" --arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token "help"
  [1]

Exact duplicate flags:

  $ use <<<'(cmd/immediate "doc" --arg :string --arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) multiple parameters with alias --arg
  [1]

Different flags, same symbol:

  $ use <<<'(cmd/immediate "doc" --arg :string ---arg :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate parameter arg
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string --foo :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate parameter foo
  [1]
  $ use <<<'(cmd/immediate "doc" [foo --arg] :string [foo --bar] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate parameter foo
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

  $ use <<<'(cmd/immediate --something {--foo 1 --bar 2})'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) you must specify all aliases for something inside {}
  [1]

Choice with aliases:

  $ use <<<'(cmd/immediate [--a --b] {--foo 1 --bar 2})'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) you must specify all aliases for a inside {}
  [1]

Duplicate aliases in choice:

  $ use <<<'(cmd/immediate choice (required {[--foo --foo] 1 --bar 2}))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) duplicate alias --foo
  [1]

Empty aliases:

  $ use <<<'(cmd/immediate [] :string)'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token []
  [1]

Empty aliases in choice:

  $ use <<<'(cmd/immediate choice (required {[] 1 --bar 2}))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) unexpected token []
  [1]

Illegal variant tagging:

  $ use <<<'(cmd/immediate choice (required @{--foo [] --bar :string}))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) expected tuple of two elements, got []
  [1]
  $ use <<<'(cmd/immediate choice (required @{--foo [:string] --bar :string}))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) expected tuple of two elements, got [:string]
  [1]
  $ use <<<'(cmd/immediate choice (required @{--foo [:tag :string foo] --bar :string}))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) expected tuple of two elements, got [:tag :string foo]
  [1]

Multiple listed positional parameters:

  $ use <<<'(cmd/immediate foo (tuple :string) bar (tuple :string))'
  $ run_err
  ! script.janet:2:1: compile error: error: (macro) you cannot specify specify multiple variadic positional parameters
  [1]
