  $ source $TESTDIR/scaffold

cmd/peg:

  $ use <<EOF
  > (def a "a")
  > (cmd/def "doc"
  >   --arg (required (cmd/peg "ab" ~(<- (* ,a "b")))))
  > (pp arg)
  > EOF

  $ run
  ! --arg: missing required argument
  [1]
  $ run --arg ab
  "ab"
  $ run --arg abc
  "ab"
  $ run --arg ba
  ! --arg: unable to parse "ba"
  [1]

Arbitrary functions:

  $ use <<EOF
  > (cmd/def "doc"
  >   --arg (required (fn [x] (string/ascii-upper x))))
  > (pp arg)
  > EOF
  $ run --arg hello
  "HELLO"

Number:

  $ use <<EOF
  > (cmd/def "doc"
  >   --arg :number)
  > (pp arg)
  > EOF
  $ run --arg 123
  123
  $ run --arg 123x
  ! --arg: 123x is not a number
  [1]

Int:

  $ use <<EOF
  > (cmd/def "doc"
  >   --int :int
  >   --non-neg :int+
  >   --pos :int++)
  > (pp [int non-neg pos])
  > EOF
  $ run --int 1 --non-neg 2 --pos 3
  (1 2 3)
  $ run --int -1 --non-neg 0 --pos 0
  ! --pos: 0 must not positive
  [1]
  $ run --int -1 --non-neg 0 --pos 1
  (-1 0 1)
  $ run --int x --non-neg 0 --pos 1
  ! --int: x is not a number
  [1]

File:

  $ use <<EOF
  > (cmd/def "doc"
  >   --arg :file)
  > (pp arg)
  > EOF
  $ run --help
  doc
  
    script.janet
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
    --arg FILE           : undocumented
  $ run --arg filename
  "filename"

Custom renamed peg:

  $ use <<EOF
  > (def host-and-port (cmd/peg "HOST:PORT" ~(group (* (<- (to ":")) ":" (number :d+)))))
  > (cmd/def address (required host-and-port))
  > (def [host port] address)
  > (print "host = " host ", port = " port)
  > EOF
  $ run localhost:1234
  host = localhost, port = 1234
  $ run --help
    script.janet HOST:PORT
  
  === flags ===
  
    [-?], [-h], [--help] : Print this help text and exit
