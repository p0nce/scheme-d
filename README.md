## What's this?

scheme-d is an incomplete Scheme interpreter in D for an easy embeddable language.


## Licenses

See UNLICENSE.txt


## Usage

See: https://github.com/p0nce/scheme-d/blob/master/examples/repl/repl.d

## Supported

- Types: double, string, bool, list, symbol, and closure (Scheme functions or D callbacks)
- pre-defined operations: https://github.com/p0nce/scheme-d/blob/master/source/schemed/environment.d#L51
- special forms: https://github.com/p0nce/scheme-d/blob/master/source/schemed/eval.d#L47
- ie. a small part of R6RS is supported

## Unsupported features

- vectors (list is already implemented with D slices)
- Scheme literals syntax for float, string or chars
- quasi-quoting
- Scheme numerical tower. Only double is provided
- char type
- most of R6RS is unsupported currently
- \x escape sequence in strings
- ie. a larger part of R6RS is unsupported

## Bugs

- symbols have too lax a grammar, should respect Extended alphabetic characters
