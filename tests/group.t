  $ source $TESTDIR/scaffold

Basic group:

  $ use <<EOF
  > (cmd/defgroup something
  >   foo (cmd/fn ["what foo does" args (escape :string)] (printf "foo called %q" args))
  >   bar (cmd/fn "what bar does" [args (escape :string)] (printf "bar called %q" args)))
  > (cmd/run something (cmd/args))
  > EOF

  $ run
  this is the docstring
  
  foo - what foo does
  bar - what bar does
  [1]

  $ run foo bar
  foo called ("bar")
  $ run bar some arguments
  bar called ("some" "arguments")
  $ run baz
  this is the docstring
  
  foo - what foo does
  bar - what bar does
  ! unknown subcommand baz
  [1]

Combining groups and functions:

  $ use <<EOF
  > (cmd/defgroup something
  >   foo (cmd/fn [--flag (flag)] (printf "foo called with %q" flag)))
  > (cmd/run something (cmd/args))
  > EOF

  $ run
  this is the docstring
  
  foo - 
  [1]

  $ run foo
  foo called with false

  $ run foo --flag
  foo called with true

Nesting groups:

  $ use <<EOF
  > (cmd/defgroup something
  >   advanced (cmd/group foo (cmd/fn [--arg :string] (print arg))
  >                       bar (cmd/fn [--other :string] (print other)))
  >   simple (cmd/fn [--easy :string] (print easy)))
  > (cmd/run something (cmd/args))
  > EOF

  $ run simple
  ! --easy: missing required argument
  [1]
  $ run simple --easy hello
  hello

  $ run advanced
  this is the docstring
  
  foo - 
  bar - 
  [1]
  $ run advanced foo
  ! --arg: missing required argument
  [1]
  $ run advanced foo --arg hi
  hi
  $ run advanced bar --other bye
  bye

Groups only show the summary line:

  $ use <<EOF
  > (cmd/defgroup something
  >   foo (cmd/fn "this is a long string\n\nhere are the details" [--arg :string] (print arg))
  >   bar (cmd/fn "only a summary line" [--easy :string] (print easy)))
  > (cmd/run something (cmd/args))
  > EOF

  $ run
  this is the docstring
  
  foo - this is a long string
  bar - only a summary line
  [1]
