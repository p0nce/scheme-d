module schemed.types;

import std.typecons,
       std.conv,
       std.string,
       std.array,
       std.algorithm,
       std.variant;


import schemed.environment;

alias Symbol = Typedef!string;

class Closure
{
public:
    this(Environment env, Atom params, Atom body_)
    {
        this.env = env;
        this.params = params;
        this.body_ = body_;
    }
    Environment env;
    Atom params;
    Atom body_;
}

// An atom is either a string, a double, a symbol, a function (env, params, body) or a list of atoms
alias Atom = Algebraic!(string, double, Symbol, Closure, This[]);


/// The one exception type thrown in this interpreter.
class SchemeException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}



Atom makeNil()
{
    Atom[] values = [];
    return Atom(values);
}

Symbol toSymbol(Atom atom)
{
    Symbol failure(Atom x0)
    {
        throw new SchemeException(format("%s is not a symbol", toString(x0)));
    }

    return atom.visit!(
        (Symbol sym) => sym,
        (string s) => failure(atom),
        (double x) => failure(atom),
        (Atom[] atoms) => failure(atom),
        (Closure fun) => failure(atom)
    );
}

bool toBool(Atom atom)
{
    bool failure(Atom x0)
    {
        throw new SchemeException(format("%s cannot be converted to a truth value", toString(x0)));
    }

    return atom.visit!(
        (Symbol sym) => failure(atom),
        (string s) => s.length > 0, // "" is falsey
        (double x) => x != 0, // 0 and NaN is falsey
        (Atom[] atoms) => failure(atom), // empty list is falsey
        (Closure fun) => failure(atom)
    );
}

string toString(Atom atom)
{
    string atomJoiner(Atom[] atoms)
    {
        return "(" ~ map!toString(atoms).joiner(" ").array.to!string ~ ")";
    }

    return atom.visit!(
        (Symbol sym) => cast(string)sym,
        (string s) => s,
        (double x) => to!string(x),
        (Atom[] atoms) => atomJoiner(atoms),
        (Closure fun) => "#<Closure>"
    );
}

Closure toClosure(Atom atom)
{
    Closure* closure = atom.peek!Closure();
    if (closure !is null)
        return *closure;
    else
        throw new SchemeException(format("%s is not a closure", toString(atom)));
}

Atom[] toList(Atom atom)
{
    Atom[]* list = atom.peek!(Atom[])();
    if (list !is null)
        return *list;
    else
        throw new SchemeException(format("%s is not a list", toString(atom)));
}

bool isList(Atom atom)
{
    return atom.peek!(Atom[])() !is null;
}

bool isSymbol(Atom atom)
{
    return atom.peek!(Symbol)() !is null;
}

bool isString(Atom atom)
{
    return atom.peek!(string)() !is null;
}

bool isDouble(Atom atom)
{
    return atom.peek!(double)() !is null;
}

bool isClosure(Atom atom)
{
    return atom.peek!(Closure)() !is null;
}