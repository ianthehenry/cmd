# `cmd` is a work in progress. It's not ready for you to use it yet!

`cmd` is a Janet library for parsing command-line arguments.

```janet
(import cmd)

(cmd/script "Print a friendly greeting"
  --greeting (optional :string "Hello")
    "What to say. Defaults to hello."
  name :string)

(printf "%s, %s!" greeting name)
```
```
$ greet Janet
Hello, Janet!
```
```
$ greet Janet --greeting "Howdy there"
Howdy there, Janet!
```
```
$ greet --help
Print a friendly greeting

  greet NAME

=== flags ===

  [--greeting STRING] : What to say. Defaults to hello.
```

# Usage

- `(cmd/script DSL)` parses `(dyn :args)` immediately and puts the results in the current scope.
- `(cmd/simple [DSL] & body)` returns a function that takes a variadic number of string arguments and parses them according to the provided spec.
- `(cmd/group & name fn)` returns a function that parses a hierarchical group.
- `(cmd/main fn)` declares a `main` function that performs argument normalization and then calls the provided function.

Additionally, you can use:

- `(cmd/spec DSL)` returns a spec as a first-class value.
- `(cmd/parse spec args)` parses the provided arguments according to the spec, and returns a table of *keywords*, not symbols.
- `(cmd/args)` returns `(dyn *args*)`, normalized according to the rules below.

There is currently no way to produce a command-line spec except by using the DSL, so it's difficult to construct one dynamically.

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

```janet
(cmd/script
  [verbosiy -v] (counter))
(printf "verbosity level: %q" verbosity)
```
```
$ run
verbosity: 0

$ run -vvv
verbosity: 3
```

## `({array,tuple}{,+} type)`

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

# `(escape &opt type)`

There are two kinds of escape: hard escape and soft escape.

A "soft escape" causes all subsequent arguments to be parsed as positional arguments. Soft escapes will not create a binding.

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

A hard escape stops all argument parsing, and creates a new binding that contains all subsequent arguments parsed according to their provided type.

```janet
(cmd/script
  name (optional :string "anonymous")
  --rest (escape :string))

(printf "Hello, %s!" name)
(pp rest)
```
```
$ run --rest Janet
Hello, anonymous!
("Janet")
```

# Positional arguments

You can mix required, optional, and variadic positional parameters, although you cannot specify more than one variadic positional parameter.

```janet
(cmd/script
  first (required :string)
  second (optional :string)
  third (required :string))
(pp [first second third])
```
```
$ run foo bar
("foo" nil "bar")

$ run foo bar baz
("foo" "bar" "baz")
```

The variadic positional parameter for a spec can be a hard escape, if it appears as the final positional parameter in your spec. The value of a hard positional escape is a tuple containing the value of that positional argument followed by all subsequent arguments (whether or not they would normally parse as `--params`).

Only the final positional argument can be an escape, and like normal variadic positional arguments, it will take lower priority than optional positional arguments.

```
(cmd/script
  name (optional :string "anonymous")
  rest (escape :string))

(printf "Hello, %s!" name)
(pp rest)
```
```
$ run Janet all the other args
Hello, Janet!
("all" "the" "other" "args")
```

# Enums

If the type of a parameter is a struct, it should enumerate a list of named parameters:

```janet
(cmd/script
  format {--text :plain
          --html :rich})

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
  format {[--text -t] :plain
          --html :rich})

(print format)
```
```
$ script -t
:plain
```

# Variants

If the type of a parameter is a table, it's parsed similarly to an enum, but will result in a value of the form `[:tag arg]`.

```janet
(cmd/script
  format @{--text :string
           --html :string})
(pp format)
```
```
$ run --text ascii
(:text "ascii")

$ run --html utf-8
(:html "utf-8")
```

You can also specify an arbitrary expression to use as a custom tag, by making the values of the table bracketed tuples of the form `[tag type]`:

```janet
(cmd/script
  format @{--text :string
           --html [(+ 1 2) :string]})
(pp format)
```
```
$ run --text ascii
(:text "ascii")

$ run --html utf-8
(3 "utf-8")
```

# Argument normalization

By default, `cmd` performs the following normalizations:

| Before       | After          |
|--------------|----------------|
| `-xyz`       | `-x -y -z`     |
| `--foo=bar`  | `--foo bar`    |
| `-xyz=bar`   | `-x -y -z bar` |

Additionally, `cmd` will detect when your script is run with the Janet interpreter (`janet foo.janet --flag`), and will automatically ignore the `foo.janet` argument.

You can bypass these normalizations by using `(cmd/parse)`, which will parse exactly the list of arguments you provide it.

# Shortcomings

You cannot make "hidden" aliases. All aliases will appear in the help output.

You cannot specify separate docstrings for different enum or variant choices. All of the parameters will be grouped into a single entry in the help output, so the docstring should describe all of the choices.

# TODO

- [ ] `--help` and `help`
- [ ] implement `cmd/group`
- [ ] more built-in type parsers
- [ ] `tuple+` and `array+`
- [ ] put brackets around `tuple` but not `tuple+` args in help output
