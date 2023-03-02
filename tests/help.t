  $ source $TESTDIR/scaffold

No docstring:

  $ use <<EOF
  > (cmd/script)
  > EOF
  $ run --help
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit

Undocumented parameters:

  $ use <<EOF
  > (cmd/script --arg :string)
  > EOF
  $ run --help
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    --arg                : undocumented

Docstring:

  $ use <<EOF
  > (cmd/script "This is the docstring")
  > EOF
  $ run --help
  This is the docstring
  
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit

Param docstring:

  $ use <<EOF
  > (cmd/script "doc" --arg :string "arg doc")
  > (pp arg)
  > EOF
  $ run --help
  doc
  
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    --arg                : arg doc

Complex help:

  $ use <<EOF
  > (cmd/script "This is the command description."
  >   foo :string
  >   bar (optional :string)
  >   rest (tuple :string)
  >   baz (optional :string)
  >   --arg (last :string) "arg help"
  >   format {--text :plain --html :rich} "how to print results"
  >   [arg-sym --alias -a --long-other-alias] :string "how to print results")
  > EOF

  $ run --help
  This is the command description.
  
    script.janet FOO [BAR] [REST...] [BAZ]
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    [--arg...]           : arg help
    -a                   : how to print results
    --alias
    --long-other-alias
    [--html], [--text]   : how to print results

Word wrap:

  $ use <<EOF
  > (cmd/print-help (cmd/spec "This is the command description."
  >   --arg :string "this is a very long docstring to demonstrate the way that word wrap behaves in help text.\n\nit can span multiple paragraphs. long words are not broken:\n\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n\nand so on"
  > ))
  > EOF

  $ run
  This is the command description.
  
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    --arg                : this is a very long docstring to demonstrate the way that
                           word wrap behaves in help text.
    
                           it can span multiple paragraphs. long words are not broken:
    
                           xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
                           and so on

Word wrap of argument names:

  $ use <<EOF
  > (cmd/print-help (cmd/spec "This is the command description."
  >   [--arg -a --bar --baz --qux] :string "this is a very long docstring to demonstrate the way that word wrap behaves in help text"
  >   --b :string "very little doc"
  > ))
  > EOF

  $ run
  This is the command description.
  
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    -a                   : this is a very long docstring to demonstrate the way that
    --arg                  word wrap behaves in help text
    --bar
    --baz
    --qux
    --b                  : very little doc
