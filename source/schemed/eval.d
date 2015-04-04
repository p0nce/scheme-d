// Inspired by lis.py
// (c) Peter Norvig, 2010; See http://norvig.com/lispy.html
module schemed.eval;

import std.string;

import schemed.types;
import schemed.environment;
import schemed.parser;


/// Execute a string of code.
/// Returns: Text representation of the result expression.
string execute(string code, Environment env)
{
    Atom result = eval(parseExpression(code), env);
    return result.toString();
}

/// Execute a string of code which may have several top-level atoms.
/// Returns: Text representation of the result expressions.
string executeScript(string code, Environment env)
{
    import std.conv: to;

    Atom[] result = eval(parseExpressions(code), env);
    return result.to!string;
}

/// Evaluates an expression.
/// Returns: Result of evaluation.
Atom eval(Atom atom, Environment env)
{
    Atom evalFailure(Atom x0)
    {
        throw new SchemeEvalException(format("%s is not a function", x0.toString()));
    }

    final switch(atom._type) with (Atom.Type)
    {
        case atomSymbol:
            return env.findSymbol(atom._symbol);
        case atomString:
        case atomDouble:
        case atomBool:
            return atom;
        case atomClosure:
            return evalFailure(atom);

        case atomList:
        {
            // empty list evaluate to itself
            if (atom._list.length == 0)
                return atom;

            Atom[] atoms = atom._list;

            Atom x0 = atoms[0];

            final switch(x0._type) with (Atom.Type)
            {
                case atomBool: return evalFailure(atom);
                case atomDouble: return evalFailure(atom);
                case atomString: return evalFailure(atom);
                case atomList: return evalFailure(atom);
                case atomClosure: return evalFailure(atom);

                case atomSymbol:
                {
                    string sym = cast(string)(x0._symbol);

                    switch(sym)
                    {
                        // Special forms
                        case "quote":
                            if (atoms.length != 2)
                                throw new SchemeEvalException("Invalid quote expression, should be (quote expr)");
                            return atoms[1];

                        case "if":
                            if (atoms.length != 3 && atoms.length != 4)
                                throw new SchemeEvalException("Invalid if expression, should be (if test-expr then-expr [else-expr])");
                            if (eval(atoms[1], env).toBool)
                                return eval(atoms[2], env);
                            else
                            {
                                if (atoms.length == 4)
                                    return eval(atoms[3], env);
                                else
                                    return makeNil();
                            }

                        case "set!":
                            if (atoms.length != 3)
                                throw new SchemeEvalException("Invalid set! expression, should be (set! var exp)");
                            env.findSymbol(atoms[1].toSymbol) = eval(atoms[2], env);
                            return makeNil();

                        case "define":
                            if (atoms.length != 3)
                                throw new SchemeEvalException("Invalid define expression, should be (define var exp) or (define (fun args...) body)");
                            if (atoms[1].isSymbol)
                                env.values[cast(string)(atoms[1].toSymbol)] = eval(atoms[2], env);
                            else if (atoms[1].isList)
                            {
                                Atom[] args = atoms[1].toList;
                                Symbol fun = args[0].toSymbol();
                                env.values[cast(string)(fun)] = Atom(new Closure(env, Atom(args[1..$]), atoms[2]));
                            }
                            else
                                throw new SchemeEvalException("Invalid define expression, should be (define var exp) or (define (fun args...) body)");
                            return makeNil();

                        case "lambda":
                            if (atoms.length != 3)
                                throw new SchemeEvalException("Invalid lambda expression, should be (lambda params body)");
                            return Atom(new Closure(env, atoms[1], atoms[2]));

                        case "begin":
                            if (atoms.length == 3)
                                return atom;
                            Atom lastValue;
                            foreach(ref Atom x; atoms[1..$])
                                lastValue = eval(x, env);
                            return lastValue;

                        // Must be a special form to enable shortcut evaluation
                        case "and":
                        case "or":
                            bool isAnd = sym == "and";
                            Atom lastValue = Atom(isAnd);
                            foreach(arg; atoms[1..$])
                            {
                                lastValue = eval(arg, env);
                                bool b = lastValue.toBool();
                                if (b ^ isAnd)
                                    break;
                            }
                            return lastValue;

                        default:
                            // function call
                            Atom[] values;
                            foreach(ref Atom x; atoms[1..$])
                                values ~= eval(x, env);
                            return apply(eval(atoms[0], env), values);
                    }
                }
            }
        }
    }
}

/// Evaluates several expressions.
/// Returns: Result of evaluation of each atom.
Atom[] eval(Atom[] atoms, Environment env)
{
    import std.array: appender;

    auto result = appender!(Atom[]);
    foreach(atom; atoms)
        result.put(eval(atom, env));
    return result.data;
}

Atom apply(Atom atom, Atom[] arguments)
{
    auto closure = atom.toClosure();

    final switch (closure.type)
    {
        // this function is regular Scheme
        case Closure.Type.regular:
            // build new environment
            Atom[] paramList = closure.params.toList();
            Atom[string] values;

            if (paramList.length != arguments.length)
                throw new SchemeEvalException(format("Expected %s arguments, got %s", paramList.length, arguments.length));

            for(size_t i = 0; i < paramList.length; ++i)
                values[cast(string)(paramList[i].toSymbol())] = arguments[i];

            Environment newEnv = new Environment(values, closure.env);
            return eval(closure.body_, newEnv);

        // this function is D code
        case Closure.Type.builtin:
            return closure.builtin(arguments);
    }
}
