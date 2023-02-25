  $ source $TESTDIR/scaffold

Cmd shouldn't export too many symbols:

  $ use <<<'(eachp [sym val] (curenv) (pp sym))'
  $ run
  cmd/number-type
  :macro-lints
  cmd/string-type
  :args
  cmd/simple
  :current-file
  :source
  cmd/immediate
