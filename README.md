## What's this?

scheme-d is an incomplete Scheme interpreter in D for an easy embeddable language.


## Licenses

See UNLICENSE.txt


## Usage


```d

import schemed;

void main()
{
    string result = execute("( + 1 (- 2 4.0) )");
}

```

## Supported

- string literals
- double literals
