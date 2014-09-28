## What's this?

scheme-d is an incomplete Scheme interpreter in D for an easy embeddable language.


## Licenses

See UNLICENSE.txt


## Usage


```d

import std.stdio;
import schemed;

void main(string[] args)
{    
    Environment env = defaultEnvironment();
    while(true)
    {
        write("> ");
        string s = readln();

        try
        {
            writeln(execute(s, env));
        }
        catch(Exception e)
        {
            writefln("Error: %s", e.msg);
        }
    }
}
```

## Supported

- string literals
- double literals
