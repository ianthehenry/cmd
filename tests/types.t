  $ source $TESTDIR/scaffold

TODO: obviously it doesn't yet...
Quasiquote creates an automatic PEG parser:

  $ use <<EOF
  > (cmd/immediate "doc"
  >   --arg ~(<- (* "a" "b")))
  > (pp arg)
  > EOF

  $ run
  ! script.janet:2:1: compile error: error: (macro) unknown type declaration ((<- (* "a" "b")))
  !   in errorf [boot.janet] (tailcall) on line 171, column 3
  !   in get-parser [$root/src/init.janet] on line 138, column 6
  !   in handle/required [$root/src/init.janet] (tailcall) on line 143, column 59
  !   in finish-arg [$root/src/init.janet] (tailcall) on line 242, column 39
  !   in parse-specification [$root/src/init.janet] on line 338, column 3
  !   in immediate [$root/src/init.janet] on line 456, column 13
  [1]
  $ run --arg ab
  ! script.janet:2:1: compile error: error: (macro) unknown type declaration ((<- (* "a" "b")))
  !   in errorf [boot.janet] (tailcall) on line 171, column 3
  !   in get-parser [$root/src/init.janet] on line 138, column 6
  !   in handle/required [$root/src/init.janet] (tailcall) on line 143, column 59
  !   in finish-arg [$root/src/init.janet] (tailcall) on line 242, column 39
  !   in parse-specification [$root/src/init.janet] on line 338, column 3
  !   in immediate [$root/src/init.janet] on line 456, column 13
  [1]
