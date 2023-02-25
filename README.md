# `cmd`

`cmd` is a Janet library for parsing command-line arguments.

```janet
(cmd/script "Print a friendly greeting"
  --greeting (optional :string "Hello")
  name :string)

(printf "%s, %s!" greeting name)
```
```
$ greet Janet
Hello, Janet!

$ greet Janet --greeting "Howdy there"
Howdy there, Janet!

$ greet --help
TODO: unimplemented
```

# Parsing behavior

By default, `cmd` performs the following normalizations:

| Before       | Becomes        |
|--------------|----------------|
| `-xyz`       | `-x -y -z`     |
| `--foo=bar`  | `--foo bar`    |
| `-xyz=bar`   | `-x -y -z bar` |

Additionally, `cmd` will detect when your script is run with the Janet interpreter (`janet foo.janet --flag`), and will automatically ignore the `foo.janet` argument.

You can bypass these normalizations by using some of the lower-level `cmd` helpers.

# Aliases

You can specify multiple aliases for named parameters:

```janet
(cmd/script
  [--foo -f] :string)
(print foo)
```
```
$ run -f hello
hello
```

By default `cmd` will create a binding based on the first provided alias. If you want to change this, specify a symbol without any leading dashes:

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

Positional parameters have the same handlers, except that they cannot be `flag` or `counted`.

There is also a special handler called `(escape)`, described below.

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

## `(tuple t)` `(array t)` `(tuple+ t)` `(array+ t)`

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

## `(last type)` and `(last? type &opt default)`

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

# `(escape &opt arg)`

There are two kinds of escape: hard escape and soft escape.

A "soft escape" causes all subsequent arguments to be parsed as positional arguments. It will not create a binding.

```janet
(cmd/script
  name :string
  -- (escape))
(printf "Hello, %s!" name)
```
```
$ run -- --bobby-tables
Hello, --bobby-tables!
```

A hard escape stops all argument parsing, and creates a new binding that contains all subsequent arguments as strings.

```
(cmd/script
  name (optional :string "anonymous")
  rest (escape --))

(printf "Hello, %s!" name)
(pp rest)
```
```
$ run -- Janet
Hello, anonymous!
("Janet")
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
- [ ] `foo=bar` argument handling
- [ ] `-xyz` argument handling
- [ ] `--help` and `help`
- [ ] `--` hard and soft escape handlers
