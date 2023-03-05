  $ source $TESTDIR/scaffold

Effects:

  $ use <<EOF
  > (cmd/def
  >   --version (effect (fn [] (print "VERSION") (os/exit 0))))
  > (print "program")
  > EOF

  $ run
  program
  $ run --version
  VERSION
