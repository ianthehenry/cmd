  $ source $TESTDIR/scaffold

cmd/peg:

  $ use <<EOF
  > (def a "a")
  > (cmd/def "doc"
  >   --arg (required (cmd/peg ~(<- (* ,a "b")))))
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

Custom renamed peg:

  $ use <<EOF
  > (def host-and-port ["HOST:PORT" (cmd/peg ~(group (* (<- (to ":")) ":" (number :d+))))])
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
