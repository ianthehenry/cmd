  $ source $TESTDIR/scaffold

  $ cat >project.janet <<EOF
  > (declare-project
  >   :name "hello")
  > (declare-executable
  >   :name "hello"
  >   :entry "main.janet")
  > EOF

  $ cat >main.janet <<EOF
  > #!/usr/bin/env janet
  > (import cmd)
  > (cmd/main (cmd/fn [--name :string]
  >   (print "Hello, " name "!")))
  > EOF
  $ mkdir -p jpm_tree/lib
  $ ln -s $TESTDIR/../src jpm_tree/lib/cmd
  $ jpm -l janet main.janet --name tester
  Hello, tester!
  $ jpm -l build >/dev/null 2>/dev/null
  $ build/hello --name tester
  Hello, tester!
  $ chmod +x main.janet
  $ JANET_PATH=jpm_tree/lib ./main.janet --name tester
  Hello, tester!
