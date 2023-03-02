  $ source $TESTDIR/scaffold

Positional parameters are required by default:

  $ use <<EOF
  > (cmd/script
  >   arg :string)
  > (print arg)
  > EOF

  $ run
  ! not enough arguments
  [1]
  $ run foo
  foo
  $ run foo bar
  ! unexpected argument bar
  [1]

Multiple positional parameters:

  $ use <<EOF
  > (cmd/script
  >   first :string
  >   second :string)
  > (print first)
  > (print second)
  > EOF

  $ run
  ! not enough arguments
  [1]
  $ run foo
  ! not enough arguments
  [1]
  $ run foo bar
  foo
  bar

Optional positional parameters:

  $ use <<EOF
  > (cmd/script
  >   first :string
  >   second (optional :string "dflt"))
  > (pp [first second])
  > EOF

  $ run foo
  ("foo" "dflt")
  $ run foo bar
  ("foo" "bar")

  $ use <<EOF
  > (cmd/script
  >   first (optional :string "dflt")
  >   second :string)
  > (pp [first second])
  > EOF

  $ run foo
  ("dflt" "foo")
  $ run foo bar
  ("foo" "bar")

Optional and required positional parameters interspersed:

  $ use <<EOF
  > (cmd/script
  >   first :string
  >   second (optional :string)
  >   third (optional :string)
  >   fourth :string)
  > (pp [first second third fourth])
  > EOF

  $ run 1 2
  ("1" nil nil "2")
  $ run 1 2 3
  ("1" "2" nil "3")
  $ run 1 2 3 4
  ("1" "2" "3" "4")

Variadic positional parameters:

  $ use <<EOF
  > (cmd/script
  >   arg (tuple :string))
  > (pp arg)
  > EOF

  $ run
  ()
  $ run 1
  ("1")
  $ run 1 2
  ("1" "2")

Variadic and required positional parameters:

  $ use <<EOF
  > (cmd/script
  >   first (tuple :string)
  >   second :string)
  > (pp [first second])
  > EOF

  $ run 1
  (() "1")
  $ run 1 2
  (("1") "2")
  $ run 1 2 3
  (("1" "2") "3")

  $ use <<EOF
  > (cmd/script
  >   first :string
  >   second (tuple :string))
  > (pp [first second])
  > EOF

  $ run 1
  ("1" ())
  $ run 1 2
  ("1" ("2"))
  $ run 1 2 3
  ("1" ("2" "3"))

Optional parameters take precedence over variadic parameters:

  $ use <<EOF
  > (cmd/script
  >   first (tuple :string)
  >   second (optional :string))
  > (pp [first second])
  > EOF

  $ run
  (() nil)
  $ run 1
  (() "1")
  $ run 1 2
  (("1") "2")
  $ run 1 2 3
  (("1" "2") "3")

Optional, required, and variadic parameters:

  $ use <<EOF
  > (cmd/script
  >   first (optional :string)
  >   second (tuple :string)
  >   third :string
  >   fourth (optional :string)
  >   fifth :string)
  > (pp [first second third fourth fifth])
  > EOF

  $ run 1 2
  (nil () "1" nil "2")
  $ run 1 2 3
  ("1" () "2" nil "3")
  $ run 1 2 3 4
  ("1" () "2" "3" "4")
  $ run 1 2 3 4 5
  ("1" ("2") "3" "4" "5")
  $ run 1 2 3 4 5 6
  ("1" ("2" "3") "4" "5" "6")
