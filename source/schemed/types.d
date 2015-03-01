module schemed.types;

import std.typecons,
       std.conv,
       std.string;


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

struct Atom
{
package:
    Type _type;
    string _string;
    double _double;
    bool _bool;
    Symbol _symbol;
    Closure _closure;
    Atom[] _list;

public:
    enum Type
    {
        atomString,
        atomDouble,
        atomList,
        atomBool,
        atomSymbol,
        atomClosure
    }

    this(string s)
    {
        _type = Type.atomString;
        _string = s;
    }

    this(double d)
    {
        _type = Type.atomDouble;
        _double = d;
    }

    this(Atom[] d)
    {
        _type = Type.atomList;
        _list = d.dup;
    }

    this(bool b)
    {
        _type = Type.atomBool;
        _bool = b;
    }

    this(Symbol s)
    {
        _type = Type.atomSymbol;
        _symbol = s;
    }

    this(Closure c)
    {
        _type = Type.atomClosure;
        _closure = c;
    }

    // R5RS "Except for #f, all standard Scheme values, including #t, pairs, the empty list, symbols, numbers, strings, vectors, and procedures, count as true."
    bool toBool()
    {
        if (_type == Type.atomBool)
            return _bool;
        else
            return true;
    }

    string toString()
    {
        final switch(_type) with (Type)
        {
            case atomString: return _string;
            case atomDouble: return to!string(_double);
            case atomList:
            {
                string s = "(";
                foreach(int i, ref atom; _list)
                {
                    if (i > 0) s ~= " ";
                    s ~= atom.toString;
                }
                s ~= ")";
                return s;
            }
            case atomBool: return (_bool ? "#t" : "#f");
            case atomSymbol: return cast(string)_symbol;
            case atomClosure: return  "#<Closure>";
        }
    }

    Closure toClosure()
    {
        if (_type != Type.atomClosure)
            throw new SchemeEvalException(format("%s is not a closure", toString()));
        return _closure;
    }

    Atom[] toList()
    {
        if (_type != Type.atomList)
            throw new SchemeEvalException(format("%s is not a list", toString()));
        return _list;
    }

    Symbol toSymbol()
    {
        if (_type != Type.atomSymbol)
            throw new SchemeEvalException(format("%s is not a symbol", toString()));
        return _symbol;
    }

    double toDouble()
    {
        if (_type != Type.atomDouble)
            throw new SchemeEvalException(format("%s is not a number", toString()));
        return _double;
    }

    bool isList() pure const nothrow @nogc
    {
        return (_type == Type.atomList);
    }

    bool isSymbol() pure const nothrow @nogc
    {
        return (_type == Type.atomSymbol);
    }

    bool isString() pure const nothrow @nogc
    {
        return (_type == Type.atomString);
    }

    bool isDouble() pure const nothrow @nogc
    {
        return (_type == Type.atomDouble);
    }

    bool isClosure() pure const nothrow @nogc
    {
        return (_type == Type.atomClosure);
    }

    bool isBool() pure const nothrow @nogc
    {
        return (_type == Type.atomBool);
    }
}


/// The exception type thrown in this interpreter.
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

/// Thrown when code did not parse.
class SchemeParseException : SchemeException
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// Thrown when code did not evaluate.
class SchemeEvalException : SchemeException
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


