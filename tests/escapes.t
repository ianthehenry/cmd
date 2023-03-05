  $ source $TESTDIR/scaffold

Soft escapes cause all arguments to be parsed positionally:

  $ use <<EOF
  > (cmd/def
  >   --arg (optional :string)
  >   name :string
  >   -- (escape))
  > (pp [arg name])
  > EOF

  $ run -- --arg
  (nil "--arg")

Soft escapes do not create a binding:

  $ use <<EOF
  > (cmd/def
  >   --foo (escape))
  > (pp foo)
  > EOF
  $ run_err
  ! script.janet:4:1: compile error: unknown symbol foo
  [1]

# TODO: this should probably be an error?
Renamed soft escape are ignored:

  $ use <<EOF
  > (cmd/def
  >   foo :string
  >   [foo --bar] (escape))
  > (pp foo)
  > EOF
  $ run hello --bar
  "hello"

You can have multiple soft escapes:

  $ use <<EOF
  > (cmd/def
  >   --arg (optional :string)
  >   name :string
  >   --foo (escape)
  >   --bar (escape))
  > (pp [arg name])
  > EOF
  $ run --foo --arg
  (nil "--arg")
  $ run --bar --arg
  (nil "--arg")

Hard escapes stop all subsequent command-line handling:

  $ use <<EOF
  > (cmd/def
  >   foo (optional :string)
  >   --arg (optional :string)
  >   --esc (escape :string))
  > (pp [foo arg esc])
  > EOF
  $ run --esc --arg hello
  (nil nil ("--arg" "hello"))
  $ run --arg hello --esc --arg hello
  (nil "hello" ("--arg" "hello"))
  $ run foo --arg hello --esc --arg hello
  ("foo" "hello" ("--arg" "hello"))

Anonymous hard escapes:

  $ use <<EOF
  > (cmd/def
  >   foo (optional :string)
  >   --arg (optional :string)
  >   esc (escape :string))
  > (pp [foo arg esc])
  > EOF
  $ run
  (nil nil ())
  $ run foo
  ("foo" nil ())
  $ run foo bar
  ("foo" nil ("bar"))
  $ run foo bar --arg hello
  ("foo" nil ("bar" "--arg" "hello"))
  $ run --arg hello foo bar --arg hello
  ("foo" "hello" ("bar" "--arg" "hello"))
  $ run foo --arg hello bar --arg hello
  ("foo" "hello" ("bar" "--arg" "hello"))
