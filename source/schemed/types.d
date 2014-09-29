module schemed.types;

import std.typecons,
       std.conv,
       std.string,
       std.array,
       std.algorithm,
       std.variant;


import schemed.environment;

alias Symbol = Typedef!string;

alias Builtin = Atom delegate(Atom[] args);

/// A Closure is either a native Scheme function or a builtin.
class Closure
{
public:

    enum Type
    {
        regular,
        builtin
    }

    /// Builds a regular closure
    this(Environment env, Atom params, Atom body_)
    {
        this.type = Type.regular;
        this.env = env;
        this.params = params;
        this.body_ = body_;
        this.builtin = null;
    }

    /// Builds a builtin closure
    this(Builtin builtin)
    {
        this.type = Type.builtin;
        this.env = null;
        this.builtin = builtin;
    }

    Type type;
    Environment env;
    Atom params;
    Atom body_;
    Builtin builtin;
}

// An Atom is either:
// - a string 
// - a double
// - a bool
// - a symbol
// - a function (env, params, body) 
// or a list of atoms
alias Atom = Algebraic!(string, double, bool, Symbol, Closure, This[]);


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


// R5RS "Except for #f, all standard Scheme values, including #t, pairs, the empty list, symbols, numbers, strings, vectors, and procedures, count as true."
bool toBool(Atom atom)
{
    bool* b = atom.peek!bool();

    if (b is null)
        return Atom(true);

    return *b;
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
        (bool b) => (b ? "#t" : "#f"),
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

Symbol toSymbol(Atom atom)
{
    Symbol* s = atom.peek!Symbol();
    if (s !is null)
        return *s;
    else
        throw new SchemeException(format("%s is not a symbol", toString(atom)));
}

double toDouble(Atom atom)
{
    double* d= atom.peek!(double)();
    if (d !is null)
        return *d;
    else
        throw new SchemeException(format("%s is not a number", toString(atom)));
}

bool isList(Atom atom)
{
    return atom.peek!(Atom[])() !is null;
}

bool isSymbol(Atom atom)
{
    return atom.peek!Symbol() !is null;
}

bool isString(Atom atom)
{
    return atom.peek!string() !is null;
}

bool isDouble(Atom atom)
{
    return atom.peek!double() !is null;
}

bool isClosure(Atom atom)
{
    return atom.peek!Closure() !is null;
}

bool isBool(Atom atom)
{
    return atom.peek!bool() !is null;
}