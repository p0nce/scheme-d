module schemed.parser;

import std.range;
import std.ascii;
import std.string;
import std.conv;

import schemed.types;
import schemed.environment;

public
{

    /// Parse a chain of code. Must be a s-expr else SchemeException will be thrown.
    /// The string MUST contain only one atom. An input like "1 2 3" won't be accepted.
    Atom parseExpression(string code)
    {
        auto parser = Parser(code);
        Atom result = parser.parseExpr();

        TokenType lastToken = parser.peekToken().type;
        // input should be finished there
        if (lastToken != TokenType.endOfInput)
            throw new SchemeParseException(format("Parsed one expression '%s' but the input is not fully consumed", result.toString())); // TODO return evaluation of last Atom parsed

        return result;
    }

    /// Parse a sequence of expressions.
    Atom[] parseExpressions(string source)
    {
        import std.array: appender;

        auto parser = Parser(source);
        auto result = appender!(Atom[]);

        do
            result.put(parser.parseExpr);
        while(parser.peekToken.type != TokenType.endOfInput);

        return result.data;
    }

}

private
{

    enum TokenType
    {
        leftParen,
        rightParen,
        symbol,
        stringLiteral,
        numberLiteral,
        singleQuote,
        boolLiteral,
        endOfInput
    }

    struct Token
    {
        TokenType type;
        int line;
        int column;
        string stringValue;
        double numValue;
    }

    struct Lexer(R) if (isInputRange!R && is(ElementType!R : dchar))
    {
    public:
        this(R input)
        {
            _input = input;
            _state = State.initial;
            _currentLine = 0;
            _currentColumn = 0;
        }

        Token nextToken()
        {
            string currentString;

            while(true)
            {
                if (_input.empty)
                    return Token(TokenType.endOfInput, _currentLine, _currentColumn, "", double.nan);

                dchar ch = _input.front();
                bool ascii = isASCII(ch);
                bool control = isControl(ch);
                bool whitespace = isWhite(ch);
                bool punctuation = isPunctuation(ch);
                bool alpha = isAlpha(ch);
                bool digit = isDigit(ch);

                final switch(_state) with (State)
                {
                    case initial:
                        if (!ascii)
                            throw new SchemeParseException(format("Non-ASCII character found: '%s'", ch));

                        // skip whitespace
                        if (isWhite(ch))
                        {
                            popChar();
                            break;
                        }

                        if (control)
                            throw new SchemeParseException("Control character found");

                        if (ch == '#')
                        {
                            popChar();
                            _state = insideBoolLiteral;
                        }
                        else if (ch == ';')
                        {
                            popChar();
                            _state = insideSingleLineComment;
                        }
                        else if (ch == '\'')
                        {
                            popChar();
                            return Token(TokenType.singleQuote, _currentLine, _currentColumn, "", double.nan);
                        }
                        else if (ch == '(')
                        {
                            popChar();
                            return Token(TokenType.leftParen, _currentLine, _currentColumn, "", double.nan);
                        }
                        else if (ch == ')')
                        {
                            popChar();
                            return Token(TokenType.rightParen, _currentLine, _currentColumn, "", double.nan);
                        }
                        else if (digit || ch == '+' || ch == '-' || ch == '.')
                        {
                            _state = insideNumber;
                            currentString = "";
                            currentString ~= ch;
                            popChar();
                        }
                        else if (ch == '"')
                        {
                            _state = insideString;
                            currentString = "";
                            popChar();
                        }
                        else if (isIdentifierChar(ch))
                        {
                            _state = insideSymbol;
                            currentString = "";
                            currentString ~= ch;
                            popChar();
                        }
                        else
                            throw new SchemeParseException(format("Unexpected character '%s'", ch));
                        break;

                    // comments are dropped by the lexer
                    case insideSingleLineComment:
                        popChar();
                        if (ch == '\n')
                            _state = initial;
                        break;

                    case insideString:
                        popChar();
                        if (ch == '\\')
                            _state = insideStringEscaped;
                        else if (ch == '"')
                        {
                             _state = initial;
                            return Token(TokenType.stringLiteral, _currentLine, _currentColumn, currentString, double.nan);
                        }
                        else
                            currentString ~= ch;
                        break;

                    case insideStringEscaped:
                        popChar();
                        if (ch == '\\')
                            currentString ~= '\\';
                        else if (ch == 'a')
                            currentString ~= '\a';
                        else if (ch == 'b')
                            currentString ~= '\b';
                        else if (ch == 't')
                            currentString ~= '\t';
                        else if (ch == 'n')
                            currentString ~= '\n';
                        else if (ch == 'v')
                            currentString ~= '\v';
                        else if (ch == 'f')
                            currentString ~= '\f';
                        else if (ch == 'r')
                            currentString ~= '\r';
                        else if (ch == '"')
                            currentString ~= '"';
                        else
                            throw new SchemeParseException("Unknown escape sequence");
                        _state = insideString;
                        break;

                    case insideNumber:
                        
                        if (whitespace || ch == '(' || ch == ')' || ch == ';')
                        {
                            _state = initial;
                            assert(currentString.length > 0);

                            // special case who are actually symbols
                            if (currentString == "+" || currentString == "-"  || currentString == "...")
                                return Token(TokenType.symbol, _currentLine, _currentColumn, currentString, double.nan);

                            static bool tryParseDouble(string input, out double result) 
                            {
                                import core.stdc.stdio;
                                import std.string;
                                return sscanf(input.toStringz, "%lf".toStringz, &result) == 1;
                            }

                            double d;
                            if (tryParseDouble(currentString, d))
                                return Token(TokenType.numberLiteral, _currentLine, _currentColumn, "", d);
                            else
                                throw new SchemeParseException(format("'%s' cannot be parsed as a number", currentString));
                        }
                        else if (isDigit(ch) || ch == '+' || ch == '-' || ch == 'e' || ch == '.' || ch == '_')
                        {
                            currentString ~= ch;
                            popChar();
                        }
                        else
                            throw new SchemeParseException(format("Unexpected character '%s' in a number literal", ch));
                        break;

                    case insideBoolLiteral:
                        if (ch == 't')
                        {
                            _state = initial;
                            popChar();
                            return Token(TokenType.boolLiteral, _currentLine, _currentColumn, "", 1.0);
                        }
                        else if (ch == 'f')
                        {
                            _state = initial;
                            popChar();
                            return Token(TokenType.boolLiteral, _currentLine, _currentColumn, "", 0.0);                            
                        }
                        else
                            throw new SchemeParseException(format("Unexpected character '%s' in a bool literal", ch));

                    case insideSymbol:

                        if (whitespace || ch == '(' || ch == ')' || ch == ';')
                        {
                            _state = initial;
                            assert(currentString.length > 0);  
                            return Token(TokenType.symbol, _currentLine, _currentColumn, currentString, double.nan);
                        }
                        else if (isIdentifierChar(ch) || digit)
                        {
                            currentString ~= ch;
                            popChar();
                        }
                        else
                            throw new SchemeParseException(format("Unexpected character '%s' in a symbol", ch));
                        break;
                }
            }
        }

    private:
        R _input;
        State _state;
        int _currentLine;
        int _currentColumn;

        static bool isIdentifierChar(dchar ch)
        {
            static immutable dstring extendedAlpha = "!$%&*+-./:<=>?@^_~";
            return isAlpha(ch) || indexOf(extendedAlpha, ch) != -1;
        }

        enum State
        {
            initial,
            insideString,
            insideStringEscaped,
            insideSymbol,
            insideNumber,
            insideSingleLineComment,
            insideBoolLiteral
        }

        void popChar()
        {
            assert(!_input.empty);
            dchar ch = _input.front();
            _input.popFront();

            if (ch == '\n')
            {
                _currentLine++;
                _currentColumn = 0;
            }
            else
                _currentColumn++;
        }
    }

    struct Parser
    {
    public:
        this(string code)
        {
            _lexer = Lexer!string(code);
            popToken();
        }

        Token peekToken()
        {        
            return _currentToken;
        }

        void popToken()
        {
            _currentToken = _lexer.nextToken();
        }

        Atom parseExpr()
        {
            Token token = peekToken();

            final switch (token.type) with (TokenType)
            {
                case leftParen:
                    Atom[] atoms = parseList();
                    return Atom(atoms);

                case rightParen:
                    throw new SchemeParseException("Unexpected ')'");

                // quoted expression
                case singleQuote:
                    popToken();
                    auto atom = parseExpr();
                    return Atom([ Atom(cast(Symbol)("quote")), atom ]);

                case symbol:
                    popToken();
                    return Atom(cast(Symbol)token.stringValue);

                case stringLiteral:
                    popToken();
                    return Atom(token.stringValue);

                case numberLiteral:
                    popToken();
                    return Atom(token.numValue);

                case boolLiteral:
                    popToken();
                    return Atom(token.numValue != 0);

                case endOfInput:
                    throw new SchemeParseException("Expected an expression, got end of input");
            }
        }

        Atom[] parseList()
        {
            popToken();
            Atom[] atoms;
            while (true)
            {
                Token token = peekToken();
                if (token.type == TokenType.endOfInput)
                {
                    throw new SchemeParseException("Expected ')', got end of input");
                }
                else if (token.type == TokenType.rightParen)
                {
                    popToken();
                    return atoms;
                }
                else
                    atoms ~= parseExpr();
            }
        }

    private:
        Lexer!string _lexer;
        Token _currentToken;
    }

}
