import std.stdio;
import schemed;
import colorize;

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

    cwriteln("Welcome to scheme-d REPL, type '(exit)' to quit.".color(fg.light_white));

    while(!exit)
    {
        cwrite("> ".color(fg.light_yellow));

        string s = readln();

        try
        {
            cwriteln(color("=> " ~ execute(s, env), fg.light_cyan));
        }
        catch(Exception e)
        {
            cwritefln("Error: %s".color(fg.light_red), e.msg);
        }
        writeln();
    }
}


