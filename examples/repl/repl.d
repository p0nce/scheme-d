import std.stdio;
import schemed;

void main(string[] args)
{
    Environment env = defaultEnvironment();

    bool exit = false;

    // Adds a builtin function
    env.values["exit"] = Atom(new Closure(
        (Atom[] args)
        {
            exit = true;
            return makeNil();
        }));

    writeln("Welcome to scheme-d REPL, type '(exit)' to quit.");

    while(!exit)
    {
        write("> ");

        string s = readln();

        try
        {
            writeln("=> " ~ execute(s, env));
        }
        catch(Exception e)
        {
            writefln("Error: %s");
        }
        writeln();
    }
}


