  $ source $TESTDIR/scaffold

Cmd shouldn't export too many symbols:

  $ use <<<'(loop [[sym val] :pairs (curenv) :when (symbol? sym)] (pp sym))'
  $ run
  cmd/parse
  cmd/defgroup
  cmd/defn
  cmd/print-help
  cmd/spec
  cmd/def
  cmd/args
  cmd/group
  cmd/fn
  cmd/run

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

cmd/print-help:

  $ use <<EOF
  > (cmd/print-help (cmd/spec --arg :string))
  > EOF
  $ run
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    --arg STRING         : undocumented
