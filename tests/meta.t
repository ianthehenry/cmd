  $ source $TESTDIR/scaffold

Cmd shouldn't export too many symbols:

  $ use <<<'(eachp [sym val] (curenv) (pp sym))'
  $ run
  :args
  cmd/simple
  :current-file
  :source
  cmd/immediate
  :macro-lints
