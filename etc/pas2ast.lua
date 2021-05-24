-- Parses a Pascal file according to the grammar below, and returns its AST
-- http://www.davidghoyle.co.uk/WordPress/?page_id=1389

-- Requires
local ddlt = require 'ddlt'
local access = require 'access'
local paspp = require 'paspp'

-- Returns a new parser for the given file
local function newParser(path, macros)
    -- Tokenizes Pascal source code
    local function tokenize(source)
        -- Creates the parser
        local lexer = ddlt.newLexer{
            file = path,
            source = source,
            language = 'pas',
            symbols = {
                ';', ',', '=', '(', ')', ':', '+', '[', ']', '..', '.', '-', '*', '<', '>', '/', ':=', '<=', '>=', '<>'
            },

            keywords = {
                'real48', 'real', 'single', 'double', 'extended', 'currency', 'comp', 'shortint', 'smallint', 'integer', 'byte',
                'longint', 'int64', 'word', 'boolean', 'char', 'widechar', 'longword', 'pchar', 'string',
                'div', 'mod', 'and', 'or', 'in', 'is',
                'unit', 'interface', 'uses', 'type', 'true', 'false', 'class', 'end', 'procedure', 'function', 'var', 'const', 'array',
                'initialization', 'nil',
                'of', 'record', 'implementation', 'begin', 'not',
                'if', 'then', 'else', 'for', 'to', 'downto', 'do', 'while', 'case', 'repeat', 'until'
            }
        }

        -- Tokenizes the entire file
        local tokens = {}
        local la

        repeat
            -- Don't add comments to the token list
            repeat
                la = assert(lexer:next({}))
            until la.token ~= '<linecomment>' and la.token ~= '<blockcomment>'

            tokens[#tokens + 1] = la
        until la.token == '<eof>'

        return tokens
    end

    -- Pre-processes Pascal source code
    local function preprocess(source)
        local tokens = tokenize( source)
        local source = assert(paspp(path, tokens))
        return load(source)()(macros)
    end

    -- Try to open and read the input file
    local input, err = io.open(path, 'r')

    if not input then
        error(string.format('%s:0: Error opening input file: %s', path, err))
    end

    local source = input:read('*a')
    input:close()

    source = preprocess(source)
    local tokens = tokenize(source)

    -- Creates and returns the parser instance
    return access.record {
        tokens = access.const(tokens),
        current = 1,

        error = function(self, line, format, ...)
            error(string.format('%s:%d: %s', path, line, string.format(format, ...)))
        end,

        token = function(self, offset)
            return self.tokens[self.current + (offset or 0)].token
        end,

        lexeme = function(self, offset)
            return self.tokens[self.current + (offset or 0)].lexeme
        end,

        line = function(self, offset)
            return self.tokens[self.current + (offset or 0)].line
        end,

        match = function(self, token)
            if token ~= self:token() then
                self:error(self:line(), '"%s" expected, found "%s"', token, self:token())
            end

            self.current = self.current + 1
        end,

        parse = function(self)
            if self:token() == 'program' then
                local ast = self:parseProgram()
                self:match('<eof>')
                return ast
            elseif self:token() == 'unit' then
                local ast = self:parseUnit()
                self:match('<eof>')
                return ast
            else
                self:error(self:line(), '"program" or "unit" expected, found "%s"', self:token())
            end
        end,

        parseProgram = function(self)
            self:error(self:line(), 'Only units are supported')
        end,

        parseUnit = function(self)
            self:match('unit');

            local id = self:lexeme()
            self:match('<id>')
            self:match(';')

            local interface = self:parseInterfaceSection()
            local implementation = self:parseImplementationSection()
            local initialization = self:parseInitializationSection()

            self:match('.')

            return access.const {
                type = 'unit', 
                id = id,
                interface = interface,
                implementation = implementation,
                initialization = initialization
            }
        end,

        parseInterfaceSection = function(self)
            self:match('interface')

            local uses = nil

            if self:token() == 'uses' then
                uses = self:parseUsesClause()
            end

            -- InterfaceDecl
            local list = {}

            while true do
                if self:token() == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif self:token() == 'type' then
                    list[#list + 1] = self:parseTypeSection()
                elseif self:token() == 'var' then
                    list[#list + 1] = self:parseVarSection()
                elseif self:token() == 'procedure' or self:token() == 'function' then
                    list[#list + 1] = self:parseExportedHeading()
                else
                    break
                end
            end

            return access.const {
                type = 'interface',
                uses = uses,
                declarations = access.const(list)
            }
        end,

        parseImplementationSection = function(self)
            self:match('implementation')

            local uses = nil

            if self:token() == 'uses' then
                uses = self:parseUsesClause()
            end

            local list = {}

            while true do
                if self:token() == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif self:token() == 'type' then
                    list[#list + 1] = self:parseTypeSection()
                elseif self:token() == 'var' then
                    list[#list + 1] = self:parseVarSection()
                elseif self:token() == 'procedure' or self:token() == 'function' then
                    list[#list + 1] = self:parseProcedureDeclSection()
                else
                    break
                end
            end

            return access.const {
                type = 'implementation',
                uses = uses,
                declarations = access.const(list)
            }
        end,

        parseInitializationSection = function(self)
            local list = nil

            if self:token() == 'initialization' or self:token() == 'begin' then
                self:match(self:token())
                list = self:parseStmtList()
            end

            self:match('end')

            return access.const {
                type = 'initialization',
                statements = list
            }
        end,

        parseUsesClause = function(self)
            self:match('uses')
            local list = self:parseIdentList()
            self:match(';')

            return access.const {
                type = 'uses',
                units = list
            }
        end,

        parseIdentList = function(self)
            local list = {self:lexeme()}
            self:match('<id>')

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:lexeme()
                self:match('<id>')
            end

            return access.const(list)
        end,

        parseConstSection = function(self)
            self:match('const')
            local list = {}

            -- ConstantDecl
            while self:token() == '<id>' do
                local id = self:lexeme()
                self:match('<id>')

                local value, subtype

                if self:token() == '=' then
                    self:match('=')
                    value = self:parseConstExpr()
                elseif self:token() == ':' then
                    self:match(':')
                    subtype = self:parseType()
                    self:match('=')
                    value = self:parseTypedConstant()
                else
                    self:error(self:line(), '"=" or ":" expected, found "%s"', self:token())
                end

                self:match(';')

                list[#list + 1] = access.const {
                    id = id,
                    subtype = subtype,
                    value = value
                }
            end

            return access.const {
                tpye = 'const',
                constants = access.const(list)
            }
        end,

        parseConstExpr = function(self)
            return self:parseExpression()
        end,

        parseTypedConstant = function(self)
            local current = self.current
            local ok, type = pcall(self.parseRecordConstant, self)

            if ok then
                return type
            end

            self.current = current
            ok, type = pcall(self.parseArrayConstant, self)

            if ok then
                return type
            end

            self.current = current
            return self:parseConstExpr()
        end,

        parseArrayConstant = function(self)
            self:match('(')
            local list = {self:parseTypedConstant()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseTypedConstant()
            end

            self:match(')')

            return access.const {
                type = 'arrayconst',
                value = access.const(list)
            }
        end,

        parseRecordConstant = function(self)
            self:match('(')
            local list = {self:parseRecordFieldConstant()}

            while self:token() == ';' do
                self:match(';')
                list[#list + 1] = self:parseRecordFieldConstant()
            end

            self:match(')')

            return access.const {
                type = 'recordconst',
                value = access.const(list)
            }
        end,

        parseRecordFieldConstant = function(self)
            local id = self:lexeme()
            self:match('<id>')
            self:match(':')
            local value = self:parseTypedConstant()

            return access.const {
                type = 'recfield',
                id = id,
                value = value
            }
        end,

        parseExpression = function(self)
            local expr = self:parseSimpleExpression()
            local tk = self:token()

            while tk == '>' or tk == '<' or tk == '<=' or tk == '>=' or tk == '<>' or tk == 'in' or tk == 'is' or tk == '=' do
                self:match(tk)
                local left = expr
                local right = self:parseSimpleExpression()

                expr = access.const {
                    type = tk,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        parseSimpleExpression = function(self)
            local expr

            if self:token() == '+' then
                self:match('+')
                expr = self:parseTerm()
            elseif self:token() == '-' then
                self:match('-')

                expr = access.const {
                    type = 'unm',
                    operand = self:parseTerm()
                }
            else
                expr = self:parseTerm()
            end

            local tk = self:token()

            while tk == '+' or tk == '-' or tk == 'or' or tk == 'xor' do
                self:match(tk)
                local left = expr
                local right = self:parseTerm()

                expr = access.const {
                    type = tk,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        parseTerm = function(self)
            local expr = self:parseFactor()
            local tk = self:token()

            while tk == '*' or tk == '/' or tk == 'div' or tk == 'mod' or tk == 'and' or tk == 'shl' or tk == 'shr' do
                self:match(tk)
                local left = expr
                local right = self:parseFactor()

                expr = access.const {
                    type = tk,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        parseFactor = function(self)
            local tk = self:token()
            local expr

            if tk == '<id>' then
                expr = self:parseDesignator()
            elseif tk == 'true' or tk == 'false' then
                expr = access.const {
                    type = 'literal',
                    subtype = 'boolean',
                    value = tk
                }

                self:match(tk)
            elseif tk == '<decimal>' or tk == '<binary>' or tk == '<octal>' or tk == '<hexadecimal>' or tk == '<float>' then
                expr = access.const {
                    type = 'literal',
                    subtype = tk,
                    value = self:lexeme()
                }

                self:match(tk)
            elseif tk == '<string>' or tk == 'nil' then
                expr = access.const {
                    type = 'literal',
                    subtype = tk,
                    value = self:lexeme()
                }

                self:match(tk)
            elseif tk == '(' then
                self:match(tk)
                expr = self:parseExpression()
                self:match(')')
            elseif tk == 'not' then
                self:match(tk)

                expr = access.const {
                    type = 'not',
                    operand = self:parseFactor()
                }
            elseif tk == '[' then
                expr = self:parseSetConstructor()
            else
                local typeId = self:parseTypeId()
                self:match('(')
                local operand = self:parseExpression()
                self:match(')')

                expr = access.const {
                    type = 'cast',
                    typeId = typeId,
                    operand = operand
                }
            end

            return expr
        end,

        parseDesignator = function(self)
            local designator = access.const {
                type = 'variable',
                qid = self:parseQualId()
            }

            local tk = self:token()

            while tk == '.' or tk == '[' or tk == '(' do
                -- DesignatorSubElement
                if tk == '.' then
                    self:match('.')

                    designator = access.const {
                        type = 'accfield',
                        id = self:lexeme(),
                        designator = designator
                    }

                    self:match('<id>')
                elseif tk == '[' then
                    self:match('[')

                    designator = access.const {
                        type = 'accindex',
                        indices = self:parseExprList(),
                        designator = designator
                    }

                    self:match(']')
                elseif tk == '(' then
                    self:match('(')

                    designator = access.const {
                        type = 'call',
                        arguments = self:parseExprList(),
                        designator = designator
                    }

                    self:match(')')
                end

                tk = self:token()
            end

            return designator
        end,

        parseExprList = function(self)
            local list = {self:parseExpression()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseExpression()
            end

            return access.const(list)
        end,

        parseSetConstructor = function(self)
            self:match('[')
            local list = {self:parseSetElement()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseSetElement()
            end

            self:match(']')

            return access.const {
                type = 'literal',
                subtype = 'set',
                elements = access.const(list)
            }
        end,

        parseSetElement = function(self)
            local first = self:parseExpression()
            local last

            if self:token() == '..' then
                self:match('..')
                last = self:parseExpression()
            end

            return access.const {
                first = first,
                last = last
            }
        end,

        parseTypeSection = function(self)
            self:match('type')
            local list = {}

            -- TypeDecl
            repeat
                local id = self:lexeme()
                local type

                self:match('<id>')
                self:match('=')

                if self:token() == 'type' then
                    self:match('type')
                end

                if self:token() == 'class' then
                    type = self:parseRestrictedType()
                else
                    type = self:parseType()
                end

                self:match(';')

                list[#list + 1] = access.const {
                    id = id,
                    type = 'type',
                    subtype = type
                }
            until self:token() ~= '<id>'

            return access.const {
                type = 'type',
                types = access.const(list)
            }
        end,

        parseExportedHeading = function(self)
            local subtype = self:token()

            if self:token() ~= 'procedure' and self:token() ~= 'function' then
                self:error(self:line(), '"procedure" or "function" expected, "%s" found', self:token())
            end

            self:match(self:token())
            local id = self:parseQualId()
            local paramList

            if self:token() == '(' then
                paramList = self:parseFormalParameters()
            end

            local returnType

            if subtype == 'function' then
                self:match(':')
                returnType = self:parseType()
            end

            self:match(';')

            return access.const {
                type = 'heading',
                subtype = subtype,
                id = id,
                paramList = paralList,
                returnType = returnType
            }
        end,

        parseProcedureDeclSection = function(self)
            local heading = self:parseExportedHeading()
            local block = self:parseBlock()
            self:match(';')

            return access.const {
                type = 'decl',
                heading = heading,
                block = block
            }
        end,

        parseFormalParameters = function(self)
            self:match('(')
            local list = {self:parseFormalParam()}

            while self:token() == ';' do
                self:match(';')
                list[#list + 1] = self:parseFormalParam()
            end

            self:match(')')
            return access.const(list)
        end,

        parseFormalParam = function(self)
            local varaccess, isarray, value

            if self:token() == 'var' or self:token() == 'const' or self:token() == 'out' then
                varaccess = self:token()
                self:match(self:token())
            end

            -- Parameter
            local ids = self:parseIdentList()
            self:match(':')

            if self:token() == 'array' then
                isarray = true
                self:match('array')
                self:match('of')
            end

            local subtype = self:parseType()

            if not isarray and self:token() == '=' then
                self:match('=')
                value = self:parseConstExpr()
            end

            return access.const {
                type = 'param',
                access = varaccess,
                ids = ids,
                isarray = isarray,
                subtype = subtype,
                value = value
            }
        end,

        parseType = function(self)
            local tk = self:token()

            if tk == '<id>' then
                return self:parseTypeId()
            elseif tk == 'string' then
                self:match('string')
                local length

                if self:token() == '[' then
                    self:match('[')
                    length = self:parseConstExpr()
                    self:match(']')
                end

                return access.const {
                    type = 'stringtype',
                    length = length
                }
            elseif tk == 'array' then
                -- ArrayType
                self:match('array')
                local limits

                if self:token() == '[' then
                    self:match('[')
                    local list = {self:parseOrdinalType()}

                    while self:token() == ',' do
                        self:match(',')
                        list[#list + 1] = self:parseOrdinalType()
                    end

                    self:match(']')
                    limits = access.const(list)
                end

                self:match('of')
                local subtype = self:parseType()

                return access.const {
                    type = 'arraytype',
                    subtype = subtype,
                    limits = limits
                }
            elseif tk == 'record' then
                -- RecType
                return self:parseRecType()
            else
                return self:parseSimpleType()
            end
        end,

        parseRecType = function(self)
            self:match('record')
            local list = {}
            local super

            -- ClassHeritage
            if self:token() == '(' then
                self:match('(')
                local super = self:lexeme()
                self:match('<id>')
                self:match(')')
            end

            while true do
                if self:token() == '<id>' then
                    list[#list + 1] = self:parseFieldList()
                else
                    break
                end
            end

            self:match('end')

            return access.const {
                type = 'rectype',
                super = super,
                declarations = access.const(list)
            }
        end,

        parseSimpleType = function(self)
            local tk = self:token()

            if tk == 'real48' or tk == 'real' or tk == 'single' or tk == 'double' or tk == 'extended' or tk == 'currency'
                or tk == 'comp' then
                -- RealType
                self:match(tk)

                return access.const {
                    type = 'realtype',
                    subtype = tk
                }
            else
                return self:parseOrdinalType()
            end
        end,

        parseOrdinalType = function(self)
            local tk = self:token()

            if tk == '(' then
                -- EnumeratedType
                return self:parseEnumeratedType()
            elseif tk == 'shortint' or tk == 'smallint' or tk == 'integer' or tk == 'byte' or tk == 'longint' or tk == 'int64'
                or tk == 'word' or tk == 'boolean' or tk == 'char' or tk == 'widechar' or tk == 'longword' or tk == 'pchar' then
                -- OrdIdent
                self:match(tk)

                return access.const {
                    type = 'ordident',
                    subtype = tk
                }
            else
                -- SubrangeType
                local min = self:parseConstExpr()
                self:match('..')

                return access.const {
                    type = 'subrange',
                    min = min,
                    max = self:parseConstExpr()
                }
            end
        end,

        parseEnumeratedType = function(self)
            self:match('(')
            local list = {}

            -- EnumerateTypeElement
            while true do
                local id = self:lexeme()
                self:match('<id>')

                local value

                if self:token() == '=' then
                    self:match('=')
                    value = self:parseConstExpr()
                end

                list[#list + 1] = access.const {
                    id = id,
                    value = value
                }

                if self:token() ~= ',' then
                    return access.const {
                        type = 'enumerated',
                        elements = access.const(list)
                    }
                end

                self:match(',')
            end
        end,

        parseRestrictedType = function(self)
            self:match('class')

            local list = {}
            local super

            -- ClassHeritage
            if self:token() == '(' then
                self:match('(')
                super = self:lexeme()
                self:match('<id>')
                self:match(')')
            end

            while true do
                if self:token() == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif self:token() == 'type' then
                    list[#list + 1] = self:parseTypeSection()
                elseif self:token() == 'var' then
                    list[#list + 1] = self:parseVarSection()
                elseif self:token() == 'procedure' or self:token() == 'function' then
                    list[#list + 1] = self:parseExportedHeading()
                elseif self:token() == '<id>' then
                    list[#list + 1] = self:parseFieldList()
                else
                    break
                end
            end

            self:match('end')

            return access.const {
                type = 'class',
                super = super,
                declarations = access.const(list)
            }
        end,

        parseFieldList = function(self)
            local ids = self:parseIdentList()
            self:match(':')
            local subtype = self:parseType()
            self:match(';')

            return access.const {
                type = 'field',
                subtype = subtype,
                ids = ids
            }
        end,

        parseTypeId = function(self)
            local id = self:lexeme()
            self:match('<id>')

            local unitid

            if self:token() == '.' then
                unitid = id
                id = self:lexeme()
                self:match('<id>')
            end

            return access.const {
                type = 'typeid',
                id = id,
                unitid = unitid
            }
        end,

        parseQualId = function(self)
            local list = {self:lexeme()}
            self:match('<id>')

            while self:token() == '.' do
                self:match('.')
                list[#list + 1] = self:lexeme()
                self:match('<id>')
            end

            return access.const {
                type = 'qualid',
                id = list
            }
        end,

        parseVarSection = function(self)
            self:match('var')
            local list = {}

            -- VarDecl
            while self:token() == '<id>' do
                local ids = self:parseIdentList()
                self:match(':')
                local subtype = self:parseType()
                local value

                if #ids == 1 and self:token() == '=' then
                    self:match('=')
                    value = self:parseConstExpr()
                end

                list[#list + 1] = {
                    type = 'var',
                    subtype = subtype,
                    ids = ids,
                    value = value
                }

                self:match(';')
            end

            return access.const {
                type = 'variables',
                variables = access.const(list)
            }
        end,

        parseBlock = function(self)
            local list = {}

            -- DeclSection
            while true do
                if self:token() == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif self:token() == 'var' then
                    list[#list + 1] = self:parseVarSection()
                else
                    break
                end
            end

            return access.const {
                type = 'block',
                declarations = access.const(list),
                statement = self:parseCompoundStmt()
            }
        end,

        parseCompoundStmt = function(self)
            self:match('begin')
            local list

            if self:token() ~= 'end' then
                list = self:parseStmtList()
            end

            self:match('end')

            return access.const {
                type = 'compoundstmt',
                statements = access.const(list or {})
            }
        end,

        parseStmtList = function(self)
            local list = {self:parseStatement()}

            while self:token() == ';' do
                self:match(';')

                if self:token() == 'end' then
                    break
                end

                list[#list + 1] = self:parseStatement()
            end

            return access.const(list)
        end,

        parseStatement = function(self)
            local tk = self:token()

            if tk == 'begin' then
                return self:parseCompoundStmt()
            elseif tk == 'if' then
                return self:parseIfStmt()
            elseif tk == 'case' then
                return self:parseCaseStmt()
            elseif tk == 'repeat' then
                return self:parseRepeatStmt()
            elseif tk == 'while' then
                return self:parseWhileStmt()
            elseif tk == 'for' then
                return self:parseForStmt()
            elseif tk == 'with' then
                self:error(self:line(), '"with" statement not supported')
            elseif tk == '<id>' then
                return self:parseSimpleStatement()
            else
                return access.const {type = 'emptystmt'}
            end
        end,

        parseIfStmt = function(self)
            self:match('if')
            local condition = self:parseExpression()
            self:match('then')
            local ontrue = self:parseStatement()
            local onfalse

            if self:token() == 'else' then
                self:match('else')
                onfalse = self:parseStatement()
            end

            return access.const {
                type = 'if',
                condition = consition,
                ontrue = ontrue,
                onfalse = onfalse
            }
        end,

        parseCaseStmt = function(self)
            self:match('case')
            local selector = self:parseExpression()
            self:match('of')

            local list = {self:parseCaseSelector()}

            while self:token() == ';' do
                self:match(';')

                if self:token() == 'end' then
                    break
                end

                list[#list + 1] = self:parseCaseSelector()
            end

            local otherwise

            if self:token() == 'else' then
                self:match('else')
                otherwise = self:parseStatement()
            end

            if self:token() == ';' then
                self:match(';')
            end

            self:match('end')

            return access.const {
                type = 'case',
                selector = selector,
                selectors = access.const(list),
                otherwise = otherwise
            }
        end,

        parseCaseSelector = function(self)
            local list = {self:parseCaseLabel()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseCaseLabel()
            end

            self:match(':')

            return access.const {labels = list, body = self:parseStatement()}
        end,

        parseCaseLabel = function(self)
            local label = {value = self:parseConstExpr()}

            if self:token() == '..' then
                self:match('..')
                label.min = label.value
                label.value = nil
                label.max = self:parseConstExpr()
            end

            return access.const(label)
        end,

        parseRepeatStmt = function(self)
            self:match('repeat')
            local body = self:parseStatement()

            if self:token() == ';' then
                -- Not sure how to handle this, the grammar says that semicolons separate statement, not that they termintate them
                self:match(';')
            end

            self:match('until')

            return access.const {
                type = 'repeat',
                body = body,
                condition = self:parseExpression()
            }
        end,

        parseWhileStmt = function(self)
            self:match('while')
            local condition = self:parseExpression()
            self:match('do')

            return access.const {
                type = 'while',
                condition = condition,
                body = self:parseStatement()
            }
        end,

        parseForStmt = function(self)
            self:match('for')
            local variable = self:parseQualId()
            self:match(':=')
            local first = self:parseExpression()

            local direction

            if self:token() == 'to' then
                self:match('to')
                direction = 'up'
            elseif self:token() == 'downto' then
                self:match('downto')
                direction = 'down'
            else
                self:error(self:line(), '"to" or "downto" expected, found "%s"', self:token())
            end

            local last = self:parseExpression()
            self:match('do')

            return access.const {
                type = 'for',
                variable = variable,
                first = first,
                direction = direction,
                last = last,
                body = self:parseStatement()
            }
        end,

        parseSimpleStatement = function(self)
            local designator = self:parseDesignator()

            if self:token() == ':=' then
                self:match(':=')

                return access.const {
                    type = 'assignment',
                    designator = designator,
                    value = self:parseExpression()
                }
            else
                local list

                if self:token() == '(' then
                    self:match('(')
                    list = self:parseExprList()
                    self:match(')')
                end

                return access.const {
                    type = 'proccall',
                    designator = designator,
                    arguments = access.const(list or {})
                }
            end
        end
    }
end

return function(path, macros)
    local ok, parser = pcall(newParser, path, macros)

    if not ok then
        return nil, parser
    end

    local ok, ast = pcall(parser.parse, parser)

    if not ok then
        return nil, ast
    end

    return ast
end
