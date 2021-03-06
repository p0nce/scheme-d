module schemed.environment;

import std.string;

import schemed.types;

class Environment
{
public:
    this(Atom[string] values_, Environment outer_ = null)
    {
        values = values_;
        outer = outer_;
    }

    Environment outer;
    Atom[string] values;

    // Find the innermost Environment where var appears.
    Environment find(string var)
    {
        if (var in values)
            return this;
        else
        {
            if (outer is null)
                return null;
            return outer.find(var);
        }
    }
    ref Atom findSymbol(Symbol symbol)
    {
        string s = cast(string)symbol;
        Environment env = find(s);
        if (env is null)
            throw new SchemeEvalException(format("'%s' is not defined", s));

        return env.values[s];
    }

    void addBuiltin(string name, Builtin b)
    {
        values[name] = Atom(new Closure(b));
    }
}

Environment defaultEnvironment()
{
    Atom[string] builtins;

    auto env = new Environment(builtins, null);

    env.addBuiltin("+", (Atom[] args)
        {
            double sum = 0.0;
            foreach(arg; args)
                sum += arg.toDouble();
            return Atom(sum);
        });

    env.addBuiltin("*", (Atom[] args)
        {
            double result = 1.0;
            foreach(arg; args)
                result *= arg.toDouble();
            return Atom(result);
        });

    env.addBuiltin("-", (Atom[] args)
        {
            if (args.length == 0)
                throw new SchemeEvalException("Too few arguments for builtin '-', need at least 1");
            else if (args.length == 1)
                return Atom(-args[0].toDouble());
            else
            {
                double sum = args[0].toDouble();
                for(int i = 1; i < args.length; ++i)
                    sum -= args[i].toDouble();
                return Atom(sum);
            }
        });

    void addMathFunction(string fun)(string name)
    {
        import std.math;

        env.addBuiltin(name, (Atom[] args)
        {
            if (args.length != 1)
                throw new SchemeEvalException("Wrong number of arguments for builtin '" ~ fun ~ "', need exactly 1");

            double x = args[0].toDouble();
            mixin("return Atom(" ~ fun ~ ");");
        });
    }

    addMathFunction!"abs(x)"("abs");
    addMathFunction!"cast(double)exp(x)"("exp");
    addMathFunction!"cast(double)log(x)"("log");
    addMathFunction!"cast(double)sin(x)"("sin");
    addMathFunction!"cast(double)cos(x)"("cos");
    addMathFunction!"cast(double)tan(x)"("tan");
    addMathFunction!"cast(double)asin(x)"("asin");
    addMathFunction!"cast(double)acos(x)"("acos");
    addMathFunction!"cast(double)atan(x)"("atan");

    addMathFunction!"cast(double)ceil(x)"("ceiling");
    addMathFunction!"cast(double)floor(x)"("floor");
    addMathFunction!"cast(double)trunc(x)"("truncate");
    addMathFunction!"cast(double)round(x)"("round");

    addMathFunction!"x == 0"("zero?");
    addMathFunction!"x > 0"("positive?");
    addMathFunction!"x < 0"("negative?");

    addMathFunction!"x % 2 == 0"("odd?");

    // Work-around issue #13819
    // https://issues.dlang.org/show_bug.cgi?id=13819
    //addMathFunction!"x % 2 != 0"("even?");
    env.addBuiltin("even?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'even?', need exactly 1");

        double x = args[0].toDouble();
        bool result = (cast(int)x % 2) != 0;
        return Atom(result);
    });


    env.addBuiltin("/", (Atom[] args)
        {
            if (args.length == 0)
                throw new SchemeEvalException("Too few arguments for builtin '/', need at least 1");
            else if (args.length == 1)
                return Atom(1.0 / args[0].toDouble());
            else
            {
                double sum = args[0].toDouble();
                for(int i = 1; i < args.length; ++i)
                    sum /= args[i].toDouble();
                return Atom(sum);
            }
        });

    env.addBuiltin("not", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'not', need exactly 1");
        return Atom(!args[0].toBool());
    });

    env.addBuiltin("length", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'length', need exactly 1");
        return Atom(cast(double)( args[0].toList().length ));
    });

    env.addBuiltin("car", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'car', need exactly 1");
        Atom[] list = args[0].toList();
        if (list.length == 0)
            throw new SchemeEvalException("Empty list");
        return list[0];
    });

    env.addBuiltin("cdr", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'cdr', need exactly 1");
        Atom[] list = args[0].toList();
        if (list.length == 0)
            throw new SchemeEvalException("Empty list");
        return Atom(list[1..$]);
    });

    env.addBuiltin("list", (Atom[] args)
    {
        return Atom(args);
    });

    env.addBuiltin("null?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'null?', need exactly 1");
        return Atom(args[0].isList && (args[0].toList().length == 0) );
    });

    env.addBuiltin("list?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'list?', need exactly 1");
        return Atom(args[0].isList);
    });

    env.addBuiltin("symbol?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'symbol?', need exactly 1");
        return Atom(args[0].isSymbol);
    });

    env.addBuiltin("string?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'string?', need exactly 1");
        return Atom(args[0].isString);
    });

    env.addBuiltin("procedure?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'procedure?', need exactly 1");
        return Atom(args[0].isClosure);
    });

    env.addBuiltin("boolean?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'boolean?', need exactly 1");
        return Atom(args[0].isBool);
    });

    env.addBuiltin("number?", (Atom[] args)
    {
        if (args.length != 1)
            throw new SchemeEvalException("Wrong number of arguments for builtin 'number?', need exactly 1");
        return Atom(args[0].isDouble);
    });


    void addComparisonBuiltin(string op)(string name)
    {
        env.addBuiltin(name, (Atom[] args)
        {
            if (args.length < 2)
                throw new SchemeEvalException("Too few arguments for builtin '" ~ op ~ "', need at least 2");
            bool b = true;

            for (int i = 0; i < args.length - 1; ++i)
            {
                mixin("b = b & (args[i].toDouble() " ~ op ~ "args[i+1].toDouble());");
            }
            return Atom(b);
        });
    }

    addComparisonBuiltin!">"(">");
    addComparisonBuiltin!"<"("<");
    addComparisonBuiltin!">="(">=");
    addComparisonBuiltin!"<="("<=");
    addComparisonBuiltin!"=="("=");
    addComparisonBuiltin!"!="("/=");

    return env;
}
