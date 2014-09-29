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

        // input should be finished there
        if (parser.peekToken().type != TokenType.endOfInput)
            throw new SchemeException(format("Parsed one expression '%s' but the input is not fully consumed", result.toString())); // TODO return evaluation of last Atom parsed

        return result;
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
                            throw new SchemeException(format("Non-ASCII character found: '%s'", ch));

                        // skip whitespace
                        if (isWhite(ch))
                        {
                            popChar();
                            break;
                        }

                        if (control)
                            throw new SchemeException("Control character found");

                        if (ch == '\'')
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
                        else if (digit || alpha || punctuation)
                        {
                            _state = (ch == '"' ? insideString : insideSymbol);
                            currentString = "";
                            currentString ~= ch;
                            popChar();
                        }                    
                        else
                            assert(false); // all cases have been handled
                        break;

                    case insideString:
                        popChar();
                        if (ch == '\\')
                            _state = insideStringEscaped;
                        else if (ch == '"')
                            return Token(TokenType.stringLiteral, _currentLine, _currentColumn, currentString, double.nan);
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
                            throw new SchemeException("Unknown escape sequence");
                        _state = insideString;
                        break;

                    case insideSymbol:

                        if (!ascii)
                            throw new SchemeException(format("Non-ASCII character found: '%s'", ch));

                        if (whitespace || ch == '(' || ch == ')')
                        {
                            // Trivia: in Scheme difference between numbers and symbols require arbitrary look-ahead, 
                            // so numbers are parsed like symbols, but are parsable as number. At least that's what 
                            // BiwaScheme seems to do.

                            _state = initial;

                            assert(currentString.length > 0);

                            static bool tryParseDouble(string input, out double result) 
                            {
                                import core.stdc.stdio;
                                import std.string;
                                return sscanf(input.toStringz, "%lf".toStringz, &result) == 1;
                            }

                            // Is it a bool literal?
                            if (currentString == "#t")
                                return Token(TokenType.boolLiteral, _currentLine, _currentColumn, "", 1.0);
                            if (currentString == "#f")
                                return Token(TokenType.boolLiteral, _currentLine, _currentColumn, "", 0.0);
                            
                            
                            double d;
                            if (tryParseDouble(currentString, d))
                                return Token(TokenType.numberLiteral, _currentLine, _currentColumn, "", d);
                            else
                                return Token(TokenType.symbol, _currentLine, _currentColumn, currentString, double.nan);
                        }
                        else if (digit || alpha || punctuation)
                        {
                            currentString ~= ch;
                            popChar();
                        }
                        else
                            throw new SchemeException(format("Unexpected character '%s'", ch));
                        break;
                }
            }
        }

    private:
        R _input;
        State _state;
        int _currentLine;
        int _currentColumn;

        enum State
        {
            initial,
            insideString,
            insideStringEscaped,
            insideSymbol
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
                    throw new SchemeException("Unexpected right parenthesis");

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
                    throw new SchemeException("Expected an expression, got end of input");
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
                    throw new SchemeException("Expected a right parenthesis, got end of input");
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
