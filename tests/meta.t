  $ source $TESTDIR/scaffold

Cmd shouldn't export too many symbols:

  $ use <<<'(eachp [sym val] (curenv) (pp sym))'
  $ run
  cmd/parse
  cmd/print-help
  :macro-lints
  :args
  cmd/simple
  cmd/spec
  :current-file
  :source
  cmd/args
  cmd/script

cmd/spec and cmd/parse:

  $ use <<EOF
  > (def spec (cmd/spec
  >   foo :string
  >   --bar (optional string)))
  > (pp (cmd/parse spec ["hello"]))
  > (pp (cmd/parse spec ["hello" "--bar" "world"]))
  > EOF
  $ run
  @{:foo "hello"}
  @{:bar "world" :foo "hello"}

cmd/args:

  $ use <<EOF
  > (pp (cmd/args))
  > EOF
  $ run hello
  @["hello"]
  $ run --foo=bar
  @["--foo" "bar"]
  $ run --foo=bar=baz
  @["--foo" "bar=baz"]
  $ run -xyz
  @["-x" "-y" "-z"]
  $ run -xyz=foo
  @["-x" "-y" "-z" "foo"]
  $ run -x-yz
  @["-x-yz"]
  $ run "--x yz=foo"
  @["--x yz=foo"]
  $ run "-x y"
  @["-x y"]
  $ run --foo=-xyz
  @["--foo" "-xyz"]
