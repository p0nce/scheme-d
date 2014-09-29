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
            throw new SchemeException(format("'%s' is not defined", s));

        return env.values[s];
    }
}

Environment defaultEnvironment()
{
    Atom[string] builtins;

    /*
    def add_globals(env):
    "Add some Scheme standard procedures to an environment."
    import math, operator as op
    env.update(vars(math)) # sin, sqrt, ...
    env.update(
    {'not':op.not_,
    '>':op.gt, '<':op.lt, '>=':op.ge, '<=':op.le, '=':op.eq, 
    'equal?':op.eq, 'eq?':op.is_, 'length':len, 'cons':lambda x,y:[x]+y,
    'car':lambda x:x[0],'cdr':lambda x:x[1:], 'append':op.add,  
    'list':lambda *x:list(x), 'list?': lambda x:isa(x,list), 
    'null?':lambda x:x==[], 'symbol?':lambda x: isa(x, Symbol)})
    return env

    */

    builtins["+"] = Atom(new Closure((Atom[] args)
        {
            double sum = 0.0;
            foreach(arg; args)
                sum += arg.toDouble();
            return Atom(sum); 
        }));

    builtins["*"] = Atom(new Closure((Atom[] args)
        {
            double result = 1.0;
            foreach(arg; args)
                result *= arg.toDouble();
            return Atom(result); 
        }));

    builtins["-"] = Atom(new Closure((Atom[] args)
        {
            if (args.length == 0)
                throw new SchemeException("Too few arguments for builtin '-', need at least 1");
            else if (args.length == 1)
                return Atom(-args[0].toDouble());
            else
            {
                double sum = args[0].toDouble();
                for(int i = 1; i < args.length; ++i)
                    sum -= args[i].toDouble();
                return Atom(sum);
            }
        }));

    builtins["/"] = Atom(new Closure((Atom[] args)
        {
            if (args.length == 0)
                throw new SchemeException("Too few arguments for builtin '/', need at least 1");
            else if (args.length == 1)
                return Atom(1.0 / args[0].toDouble());
            else
            {
                double sum = args[0].toDouble();
                for(int i = 1; i < args.length; ++i)
                    sum /= args[i].toDouble();
                return Atom(sum);
            }
        }));

    return new Environment(builtins, null);
}
