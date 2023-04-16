  $ source $TESTDIR/scaffold

Docstrings can be dynamic expressions in def:

  $ use <<EOF
  > (cmd/def (string/format "hi %s" "there")
  >   foo :string)
  > (pp foo)
  > EOF

  $ run --help
  hi there
  
    script.janet STRING
  
  === flags ===
  
    [--help] : Print this help text and exit

Docstrings can be dynamic expressions in fn:

  $ use <<EOF
  > (cmd/main (cmd/fn (string/format "hi %s" "there")
  >   [foo :string]))
  > EOF

  $ run --help
  hi there
  
    script.janet STRING
  
  === flags ===
  
    [--help] : Print this help text and exit

Docstrings can be dynamic expressions in defn:

  $ use <<EOF
  > (cmd/defn cmd (string/format "hi %s" "there")
  >   [foo :string])
  > (cmd/main cmd)
  > EOF

  $ run --help
  hi there
  
    script.janet STRING
  
  === flags ===
  
    [--help] : Print this help text and exit

Docstrings can be dynamic expressions in group:

  $ use <<EOF
  > (cmd/main (cmd/group (string/format "hi %s" "there")
  >   foo (cmd/fn "description" [])))
  > EOF

  $ run --help
  hi there
  
    foo  - description
    help - explain a subcommand
  ! unknown subcommand --help
  [1]

Docstrings can be dynamic expressions in defgroup:

  $ use <<EOF
  > (cmd/defgroup cmd (string/format "hi %s" "there")
  >   foo (cmd/fn "description" []))
  > (cmd/main cmd)
  > EOF

  $ run --help
  hi there
  
    foo  - description
    help - explain a subcommand
  ! unknown subcommand --help
  [1]
