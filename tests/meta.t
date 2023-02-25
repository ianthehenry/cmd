  $ source $TESTDIR/scaffold

Cmd shouldn't export too many symbols:

  $ use <<<'(eachp [sym val] (curenv) (print sym))'
  $ run
  cmd/try-with-context
  cmd/new-flag-state
  cmd/catseq
  cmd/string-type
  cmd/optional
  cmd/quote-flags
  cmd/simple
  cmd/listed-array
  cmd/parse-args
  cmd/parse-form
  cmd/listed-tuple
  macro-lints
  cmd/finish-flag
  cmd/parse-specification
  cmd/parse-type
  cmd/set-ctx-doc
  cmd/type+
  cmd/unset?
  cmd/assert-unset
  cmd/counted
  cmd/state/initial
  cmd/flag
  cmd/required
  cmd/goto-state
  current-file
  cmd/immediate
  cmd/primary-name
  cmd/number-type
  cmd/print-help
  args
  cmd/quote-values
  cmd/state/flag
  source
  cmd/state/pending
  cmd/pdb
