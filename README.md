# `cmd`

`cmd` is a Janet library for parsing command-line arguments.

```
(cmd/script)
```

# Usage

```
(cmd/script "This is the help text"
  --greeting (required :string))

(print greeting)
```
```
$ run --greeting hello
hello
```

# Aliases

You can specify multiple aliases for a parameter:

```janet
(cmd/script
  [--foo -f] :string)
(print foo)
```
```
$ run -f hello
hello
```

By default `cmd` will take the name of the Janet variable to create from the first alias specified. If you want to change this, specify an alias without any leading dashes:

```janet
(cmd/script
  [custom-name --foo -f] :string)
(print custom-name)
```
```
$ run -f hello
hello
```

# Handlers

Named parameters can have the following handlers:

| Count     | `--param` | `--param value`  |
| ----------|-----------|------------------|
| 1         |           | `required` |
| 0 or 1    | `flag`    | `optional` |
| 0 or more | `counted` | `tuple`, `array`, `last?` |
| 1 or more |           | `tuple+`, `array+`, `last` |

`tuple` and `array` accumulate all instances of a flag.

## `(required type)`

You can omit this handler if your type is a keyword, struct, table, or inline PEG. The following are equivalent:

```janet
(cmd/script
  --foo :string)
```
```janet
(cmd/script
  --foo (required :string))
```

However, if you are providing a custom type parser, you need to explicitly specify the `required` handler.

```janet
(defn my-custom-parser [str] ...)
(cmd/script
  --foo (required my-custom-parser))
```

## `(optional type &opt default)`

```janet
(cmd/script
  --foo (optional :string "default value"))
(print foo)
```
```
$ run --foo hello
hello

$ run
default value
```

If left unspecified, the default default value is `nil`.

## `(flag)`

```janet
(cmd/script
  --dry-run (flag))
(printf "dry run: %q" dry-run)
```
```
$ run
dry run: false

$ run --dry-run
dry run: true
```

## `(counted)`

TODO: update once single-character splitting works

```janet
(cmd/script
  [verbosiy -v] (counter))
(printf "verbosity level: %q" verbosity)
```
```
$ run
verbosity: 0

$ run -v -v -v
verbosity: 3
```

## `(tuple)` `(array)` `(tuple+)` `(array+)`

```janet
(cmd/script
  [words --word] (tuple :string))
(pp words)
```
```
$ run --word hi --word bye
("hi" "bye")
```

`(tuple+)` and `(array+)` require that at least one argument is provided.

## `last` and `last?`

`last` is like `required`, but the parameter can be specified multiple times, and only the last argument matters.

`last?` is like `optional`, but the parameter can be specified multiple times, and only the last argument matters.

```janet
(cmd/script
  --foo (last? :string "default"))
(print foo)
```
```
$ run
default

$ run --foo hi --foo bye
bye
```

# Enums

If the type of a parameter is a struct, it should enumerate a list of named parameters:

```janet
(cmd/script
  format {--text :plain --html :rich})

(print format)
```
```
$ script --text
:plain
```

The keys of the struct are parameter names, and the values of the struct are literal Janet values.

You can use structs with the `last?` handler to implement a toggleable flag:

```janet
(cmd/script
  verbose (last? {--verbose true --no-verbose :false} false)

(print verbose)
```
```
$ run --verbose --verbose --no-verbose
false
```

You can specify aliases inside a struct like this:

```janet
(cmd/script
  format {[--text -t] :plain --html :rich})

(print format)
```
```
$ script -t
:plain
```

# Variants

NOTE: currently unimplemented

If the type of a parameter is a table, it's parsed similarly to an enum, but the values in the table should be a tuple of `[tag type]`.

```janet
(cmd/script
  format @{--text [:plain :string] --html [:rich :string]})
(pp format)
```
```
$ run --text ascii
(:plain "ascii")

$ run --html utf-8
(:rich "utf-8")
```

# Shortcomings

You cannot make "hidden" aliases. All aliases will appear in the help output.

# TODO

- [ ] anonymous arguments
- [ ] subcommands
- [ ] tagged variants
- [ ] splitting single characters
- [ ] `foo=bar` argument handling
