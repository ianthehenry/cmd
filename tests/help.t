  $ source $TESTDIR/scaffold

Executable name prints the same regardless of how it's invoked:

  $ cat >script.janet <<EOF
  > #!/usr/bin/env janet
  > (import src :as cmd)
  > (cmd/def)
  > EOF
  $ chmod +x script.janet
  $ JANET_PATH="$TESTDIR/.." ./script.janet --help
    script.janet
  
  === flags ===
  
    [--help] : Print this help text and exit
  $ JANET_PATH="$TESTDIR/.." $PWD/script.janet --help
    script.janet
  
  === flags ===
  
    [--help] : Print this help text and exit

No docstring:

  $ use <<EOF
  > (cmd/def)
  > EOF
  $ run --help
    script.janet
  
  === flags ===
  
    [--help] : Print this help text and exit

Undocumented parameters:

  $ use <<EOF
  > (cmd/def --arg :string)
  > EOF
  $ run --help
    script.janet
  
  === flags ===
  
    [--help]     : Print this help text and exit
    --arg STRING : undocumented

Hidden aliases:

  $ run -h
    script.janet
  
  === flags ===
  
    [--help]     : Print this help text and exit
    --arg STRING : undocumented
  $ run -?
    script.janet
  
  === flags ===
  
    [--help]     : Print this help text and exit
    --arg STRING : undocumented

Docstring:

  $ use <<EOF
  > (cmd/def "This is the docstring")
  > EOF
  $ run --help
  This is the docstring
  
    script.janet
  
  === flags ===
  
    [--help] : Print this help text and exit

Param docstring:

  $ use <<EOF
  > (cmd/def "doc" --arg :string "arg doc")
  > (pp arg)
  > EOF
  $ run --help
  doc
  
    script.janet
  
  === flags ===
  
    [--help]     : Print this help text and exit
    --arg STRING : arg doc

Complex help:

  $ use <<EOF
  > (cmd/def "This is the command description."
  >   foo :string
  >   bar (optional ["BAR" :string])
  >   rest (tuple :string)
  >   baz (optional ["BAZ" :string])
  >   --arg (last+ :string) "arg help"
  >   format {--text :plain --html :rich} "how to print results"
  >   [arg-sym --alias -a --long-other-alias] :string "how to print results")
  > EOF

  $ run --help
  This is the command description.
  
    script.janet STRING BAR STRING BAZ
  
  === flags ===
  
    [--help]                  : Print this help text and exit
    --arg STRING...           : arg help
    -a STRING                 : how to print results
    --alias STRING
    --long-other-alias STRING
    [--html], [--text]        : how to print results

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
  
    [--help]     : Print this help text and exit
    --arg STRING : this is a very long docstring to demonstrate the way that word wrap
                   behaves in help text.
    
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
  
    [--help]     : Print this help text and exit
    -a STRING    : this is a very long docstring to demonstrate the way that word wrap
    --arg STRING   behaves in help text
    --bar STRING
    --baz STRING
    --qux STRING
    --b STRING   : very little doc

Help for variants:

  $ use <<EOF
  > (cmd/def "This is the command description."
  >   foo (optional @{[--bar -b] [:bar ["HEY" :string]] --baz :string}) "something"
  >   other {--foo 1} "something else"
  >   something {[--arg -a] 1 [--other -o] 2} "another")
  > EOF

  $ run --help
  This is the command description.
  
    script.janet
  
  === flags ===
  
    [--help]       : Print this help text and exit
    [-b HEY]       : something
    [--bar HEY]
    [--baz STRING]
    [--foo]        : something else
    [-a]           : another
    [--arg]
    [-o]
    [--other]

Long description:

  $ use <<EOF
  > (cmd/def "This is the command summary.\n\nThis is the detailed description.\n\nIt can be multiple paragraphs long, and it does wrap properly. It looks good, even. Look at that! It looks great." foo :string)
  > EOF

  $ run --help
  This is the command summary.
  
    script.janet STRING
  
  This is the detailed description.
  
  It can be multiple paragraphs long, and it does wrap properly. It looks good,
  even. Look at that! It looks great.
  
  === flags ===
  
    [--help] : Print this help text and exit

Escapes:

  $ use <<EOF
  > (cmd/def -- (escape))
  > EOF

  $ run --help
    script.janet
  
  === flags ===
  
    [--]     : Treat all subsequent arguments as positional
    [--help] : Print this help text and exit

Examples from the readme:

  $ use <<EOF
  > (def name ["NAME" :string])
  > (cmd/def 
  >   name (required name))
  > (printf "Hello, %s!" name)
  > EOF

  $ run --help
    script.janet NAME
  
  === flags ===
  
    [--help] : Print this help text and exit

Every handler:

  $ use <<EOF
  > (cmd/def 
  >   --required (required :string)
  >   --optional (optional :string)
  >   --tuple (tuple :string)
  >   --tuple+ (tuple+ :string)
  >   --array (array :string)
  >   --array+ (array+ :string)
  >   --last (last :string)
  >   --last+ (last+ :string)
  >   --flag (flag)
  >   --effect (effect (fn []))
  >   --counted (counted)
  >   --soft-escape (escape)
  >   --hard-escape (escape :string)
  > )
  > EOF

  $ run --help
    script.janet
  
  === flags ===
  
    [--effect]                : undocumented
    [--soft-escape]           : Treat all subsequent arguments as positional
    [--help]                  : Print this help text and exit
    [--array STRING]...       : undocumented
    --array+ STRING...        : undocumented
    [--counted]               : undocumented
    [--flag]                  : undocumented
    [--hard-escape STRING...] : undocumented
    [--last STRING]...        : undocumented
    --last+ STRING...         : undocumented
    [--optional STRING]       : undocumented
    --required STRING         : undocumented
    [--tuple STRING]...       : undocumented
    --tuple+ STRING...        : undocumented

Word wrap in group help output:

  $ use <<EOF
  > (cmd/main (cmd/group
  >   foo (cmd/fn "this is a verbose description of the subcommand which will wrap and lay out nicely just like you'd expect it to" [] (print "foo"))
  >   bar (cmd/fn "this one's simple" [] (print "bar"))
  > ))
  > EOF

  $ run help
    bar  - this one's simple
    foo  - this is a verbose description of the subcommand which will wrap and lay out
           nicely just like you'd expect it to
    help - explain a subcommand

Group help for unknown subcommand:

  $ use <<EOF
  > (cmd/main (cmd/group
  >   foo (cmd/fn "this is a verbose description of the subcommand which will wrap and lay out nicely just like you'd expect it to" [] (print "foo"))
  >   bar (cmd/fn "this one's simple" [] (print "bar"))
  > ))
  > EOF

  $ run help baz
    bar  - this one's simple
    foo  - this is a verbose description of the subcommand which will wrap and lay out
           nicely just like you'd expect it to
    help - explain a subcommand
  ! unknown subcommand baz
  [1]

Subcommand --help includes the subcommand path in the usage line:

  $ use <<EOF
  > (cmd/main (cmd/group
  >   foo (cmd/fn [] (print "foo"))
  >   bar (cmd/fn [] (print "bar"))
  > ))
  > EOF

  $ run help foo
    script.janet foo
  
  
  === flags ===
  
    [--help] : Print this help text and exit

  $ run foo --help
    script.janet foo
  
  
  === flags ===
  
    [--help] : Print this help text and exit
