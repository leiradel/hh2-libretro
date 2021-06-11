-- Parses a Pascal file according to the grammar below, and returns its AST
-- http://www.davidghoyle.co.uk/WordPress/?page_id=1389

-- Requires
local ddlt = require 'ddlt'
local access = require 'access'

-- Tokenizes Pascal source code
local function tokenize(path, source)
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
            'if', 'then', 'else', 'for', 'to', 'downto', 'do', 'while', 'case', 'repeat', 'until', 'set', 'object', 'constructor',
            'destructor', 'private', 'protected', 'public', 'published', 'virtual', 'inherited', 'with'
        },

        freeform = {{'asm', 'end'}}
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

-- Preprocesses a token stream
local function preprocess(path, tokens)
    local source = {
        'return function(macros)',
        'local source = {}'
    }

    local out = function(format, ...)
        source[#source + 1] = string.format(format, ...)
    end

    for i =1, #tokens do
        local la = tokens[i]

        if la.token == '<blockdirective>' then
            local dir, id = la.lexeme:match('{%$%s*([^%s}]+)%s*}'), ''

            if not dir then
                dir, id = la.lexeme:match('{%$%s*([^%s]+)%s*([^%s}]+)%s*}')
            end

            dir, id = dir:lower(), id:lower()

            if dir == 'ifdef' then
                out('if macros.%s then', id)
            elseif dir == 'ifndef' then
                out('if not macros.%s then', id)
            elseif dir == 'else' then
                out('else')
            elseif dir == 'endif' then
                out('end')
            elseif dir == 'r' then
                -- Discard
            else
                error(string.format('%s:%u: Unhandled directive "%s"', path, la.line, dir))
            end
        elseif la.token ~= '<eof>' then
            out('source[%d] = (source[%d] or "") .. %q', la.line, la.line, la.lexeme .. ' ')
        end
    end

    source[#source + 1] = 'for i = 1, ' .. tokens[#tokens].line .. ' do'
    source[#source + 1] = 'source[i] = source[i] or ""'
    source[#source + 1] = 'end'
    source[#source + 1] = 'return table.concat(source, "\\n")'
    source[#source + 1] = 'end'

    return table.concat(source, '\n')
end

-- Returns a new parser for the given file
local function newParser(path, tokens)
    -- Creates and returns the parser instance
    return access.record {
        tokens = access.const(tokens),
        current = 1,

        error = function(self, line, format, ...)
            error(string.format('%s:%u: %s', path, line, string.format(format, ...)))
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

        -- pascal = program | unit .
        parse = function(self)
            local ast

            if self:token() == 'program' then
                ast = self:parseProgram()
            elseif self:token() == 'unit' then
                ast = self:parseUnit()
            else
                self:error(self:line(), '"program" or "unit" expected, found "%s"', self:token())
                return
            end

            self:match('<eof>')

            local new_ast = {path = path}

            for key, value in pairs(ast) do
                new_ast[key] = value
            end

            return access.const(new_ast)
        end,

        parseProgram = function(self)
            self:error(self:line(), 'Only units are supported')
        end,

        -- unit = 'unit' id ';' interface_section implementation_section initialization_section .
        parseUnit = function(self)
            local line = self:line()
            self:match('unit')

            local id = self:lexeme()
            self:match('<id>')
            self:match(';')

            local interface = self:parseInterfaceSection()
            local implementation = self:parseImplementationSection()
            local initialization = self:parseInitializationSection()

            self:match('.')

            return access.const {
                type = 'unit',
                line = line,
                id = id,
                interface = interface,
                implementation = implementation,
                initialization = initialization
            }
        end,

        -- interface_section = 'interface' [ uses_clause ] { const_section | type_section | exported_heading } .
        parseInterfaceSection = function(self)
            local line = self:line()
            self:match('interface')

            local uses = false

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
                line = line,
                uses = uses,
                declarations = access.const(list)
            }
        end,

        -- implementation_section = 'implementation' [ uses_clause ] { const_section | type_section | exported_heading } .
        parseImplementationSection = function(self)
            local line = self:line()
            self:match('implementation')

            local uses = false

            if self:token() == 'uses' then
                uses = self:parseUsesClause()
            end

            local list = {}

            while true do
                local tk = self:token()

                if tk == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif tk == 'type' then
                    list[#list + 1] = self:parseTypeSection()
                elseif tk == 'var' then
                    list[#list + 1] = self:parseVarSection()
                elseif tk == 'procedure' or tk == 'function' or tk == 'constructor' or tk == 'destructor' then
                    list[#list + 1] = self:parseProcedureDeclSection()
                else
                    break
                end
            end

            return access.const {
                type = 'implementation',
                line = line,
                uses = uses,
                declarations = access.const(list)
            }
        end,

        -- initialization_section = ( 'initialization' | 'begin' ) stmt_list 'end' .
        parseInitializationSection = function(self)
            local line = self:line()
            local list = nil

            if self:token() == 'initialization' or self:token() == 'begin' then
                self:match(self:token())
                list = self:parseStmtList()
            end

            self:match('end')

            return access.const {
                type = 'initialization',
                line = line,
                statements = list
            }
        end,

        -- uses_clause = 'uses' ident_list ';' .
        parseUsesClause = function(self)
            local line = self:line()

            self:match('uses')
            local list = self:parseIdentList()
            self:match(';')

            return access.const {
                type = 'uses',
                line = line,
                units = list
            }
        end,

        -- ident_list = id { ',' id } .
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

        -- const_section = 'const' { id ( '=' const_expr | ':' type '=' typed_constant ) } ';' .
        parseConstSection = function(self)
            local line = self:line()

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
                type = 'constants',
                line = line,
                constants = access.const(list)
            }
        end,

        -- const_expr = expression .
        parseConstExpr = function(self)
            return self:parseExpression()
        end,

        -- typed_constant = record_constant | array_constant | const_expr .
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

        -- array_constant = '(' typed_constant { ',' typed_constant } ')' .
        parseArrayConstant = function(self)
            local line = self:line()

            self:match('(')
            local list = {self:parseTypedConstant()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseTypedConstant()
            end

            self:match(')')

            return access.const {
                type = 'arrayconst',
                line = line,
                value = access.const(list)
            }
        end,

        -- record_constant = '(' record_field_constant { ';' record_field_constant } ')' .
        parseRecordConstant = function(self)
            local line = self:line()

            self:match('(')
            local list = {self:parseRecordFieldConstant()}

            while self:token() == ';' do
                self:match(';')
                list[#list + 1] = self:parseRecordFieldConstant()
            end

            self:match(')')

            return access.const {
                type = 'recordconst',
                line = line,
                value = access.const(list)
            }
        end,

        -- record_field_constant = id ':' typed_constant '.'
        parseRecordFieldConstant = function(self)
            local line = self:line()
            local id = self:lexeme()
            self:match('<id>')
            self:match(':')
            local value = self:parseTypedConstant()

            return access.const {
                type = 'recfield',
                line = line,
                id = id,
                value = value
            }
        end,

        -- expression = simple_expression { ( '>' | '<' | '<=' | '>=' | '<>' | 'in' | 'is' | '=' ) simple_expression } .
        parseExpression = function(self)
            local expr = self:parseSimpleExpression()
            local tk = self:token()

            while tk == '>' or tk == '<' or tk == '<=' or tk == '>=' or tk == '<>' or tk == 'in' or tk == 'is' or tk == '=' do
                local line = self:line()

                self:match(tk)
                local left = expr
                local right = self:parseSimpleExpression()

                expr = access.const {
                    type = tk,
                    line = line,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        -- simple_expression = [ '+' | '-' ] term { ( '+' | '-' | 'or' | 'xor' ) term  } .
        parseSimpleExpression = function(self)
            local expr

            if self:token() == '+' then
                self:match('+')
                expr = self:parseTerm()
            elseif self:token() == '-' then
                local line = self:line()
                self:match('-')

                expr = access.const {
                    type = 'unm',
                    line = line,
                    operand = self:parseTerm()
                }
            else
                expr = self:parseTerm()
            end

            local tk = self:token()

            while tk == '+' or tk == '-' or tk == 'or' or tk == 'xor' do
                local line = self:line()

                self:match(tk)
                local left = expr
                local right = self:parseTerm()

                expr = access.const {
                    type = tk,
                    line = line,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        -- term = factor { ( '*' | '/' | 'div' | 'mod' | 'and' | 'shl' | 'shr' ) factor } .
        parseTerm = function(self)
            local expr = self:parseFactor()
            local tk = self:token()

            while tk == '*' or tk == '/' or tk == 'div' or tk == 'mod' or tk == 'and' or tk == 'shl' or tk == 'shr' do
                local line = self:line()

                self:match(tk)
                local left = expr
                local right = self:parseFactor()

                expr = access.const {
                    type = tk,
                    line = line,
                    left = left,
                    right = right
                }

                tk = self:token()
            end

            return expr
        end,

        -- factor = designator | 'true' | 'false' | decimal | binary | octal | hexadecimal | float | string | 'nil'
        --        | '(' expression ')' | 'not' factor | 'inherited' designator | set_constructor |
        --        | type_id '(' expression ')' | simple_type '(' expression ')' .
        parseFactor = function(self)
            local tk = self:token()

            if tk == '<id>' then
                return self:parseDesignator()
            elseif tk == 'true' or tk == 'false' then
                local factor = access.const {
                    type = 'literal',
                    line = self:line(),
                    subtype = 'boolean',
                    value = tk
                }

                self:match(tk)
                return factor
            elseif tk == '<decimal>' or tk == '<binary>' or tk == '<octal>' or tk == '<hexadecimal>' or tk == '<float>' then
                local factor = access.const {
                    type = 'literal',
                    line = self:line(),
                    subtype = tk,
                    value = self:lexeme()
                }

                self:match(tk)
                return factor
            elseif tk == '<string>' or tk == 'nil' then
                local factor = access.const {
                    type = 'literal',
                    line = self:line(),
                    subtype = tk,
                    value = self:lexeme()
                }

                self:match(tk)
                return factor
            elseif tk == '(' then
                self:match(tk)
                local factor = self:parseExpression()
                self:match(')')
                return factor
            elseif tk == 'not' then
                local line = self:line()
                self:match(tk)

                return access.const {
                    type = 'not',
                    line = line,
                    operand = self:parseFactor()
                }
            elseif tk == 'inherited' then
                local line = self:line()
                self:match(tk)

                return access.const {
                    type = 'inherited',
                    line = line,
                    designator = self:parseDesignator()
                }
            elseif tk == '[' then
                return self:parseSetConstructor()
            else
                local line = self:line()
                local subtype

                if self:token() == '<id>' then
                    subtype = self:parseTypeId()
                else
                    subtype = self:parseSimpleType()
                end

                self:match('(')
                local operand = self:parseExpression()
                self:match(')')

                return access.const {
                    type = 'cast',
                    line = line,
                    subtype = subtype,
                    operand = operand
                }
            end
        end,

        -- designator = qual_id { '.' id | '[' expr_list ']' | '(' expr_list ')' } .
        parseDesignator = function(self)
            local line = self:line()

            local designator = access.const {
                type = 'variable',
                line = line,
                qid = self:parseQualId()
            }

            local tk = self:token()

            while tk == '.' or tk == '[' or tk == '(' do
                -- DesignatorSubElement
                if tk == '.' then
                    local line = self:line()
                    self:match('.')

                    designator = access.const {
                        type = 'accfield',
                        line = line,
                        id = self:lexeme(),
                        designator = designator
                    }

                    self:match('<id>')
                elseif tk == '[' then
                    local line = self:line()
                    self:match('[')

                    designator = access.const {
                        type = 'accindex',
                        line = line,
                        indices = self:parseExprList(),
                        designator = designator
                    }

                    self:match(']')
                elseif tk == '(' then
                    local line = self:line()
                    self:match('(')

                    designator = access.const {
                        type = 'call',
                        line = line,
                        arguments = self:parseExprList(),
                        designator = designator
                    }

                    self:match(')')
                end

                tk = self:token()
            end

            return designator
        end,

        -- expr_list = expression { ',' expression } .
        parseExprList = function(self)
            local list = {self:parseExpression()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseExpression()
            end

            return access.const(list)
        end,

        -- set_constructor = '[' set_element { ',' set_element } ']' .
        parseSetConstructor = function(self)
            local line = self:line()

            self:match('[')
            local list = {self:parseSetElement()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseSetElement()
            end

            self:match(']')

            return access.const {
                type = 'literal',
                line = line,
                subtype = 'set',
                elements = access.const(list)
            }
        end,

        -- set_element = expression [ '..' expression ] .
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

        -- type_section = 'type' { id '=' [ 'type' ] ( type | restricted_type ) ';' } .
        parseTypeSection = function(self)
            local line = self:line()
            local list = {}

            self:match('type')

            -- TypeDecl
            repeat
                local line = self:line()
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
                    type = 'type',
                    line = line,
                    id = id,
                    subtype = type
                }
            until self:token() ~= '<id>'

            return access.const {
                type = 'types',
                line = line,
                types = access.const(list)
            }
        end,

        -- procedure_heading = 'procedure' id formal_parameters .
        parseProcedureHeading = function(self, needid)
            local line = self:line()
            self:match('procedure')

            local id = false

            if needid then
                id = self:parseQualId()
            end

            local list = false

            if self:token() == '(' then
                list = self:parseFormalParameters()
            end

            return access.const {
                type = 'prochead',
                line = line,
                id = id,
                parameters = list
            }
        end,

        -- function_heading = 'function' id formal_parameters .
        parseFunctionHeading = function(self, needid)
            local line = self:line()
            self:match('function')

            local id = false

            if needid then
                id = self:parseQualId()
            end

            local list = false

            if self:token() == '(' then
                list = self:parseFormalParameters()
            end

            self:match(':')

            return access.const {
                type = 'funchead',
                line = line,
                id = id,
                parameters = list,
                returnType = self:parseType()
            }
        end,

        -- exported_heading = ( procedure_heading | function_heading ) ';' .
        parseExportedHeading = function(self)
            local heading

            if self:token() == 'procedure' then
                heading = self:parseProcedureHeading(true)
            else
                heading = self:parseFunctionHeading(true)
            end

            self:match(';')
            return heading
        end,

        -- procedure_decl_section = ( exported_heading | class_method_heading ) block ';' .
        parseProcedureDeclSection = function(self)
            local line = self:line()
            local heading

            if self:token() == 'procedure' or self:token() == 'function' then
                heading = self:parseExportedHeading(true)
            else
                heading = self:parseClassMethodHeading()
            end

            local block = self:parseBlock()
            self:match(';')

            return access.const {
                type = 'decl',
                line = line,
                heading = heading,
                block = block
            }
        end,

        -- formal_parameters = '(' formal_param { ';' formal_param } ')' .
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

        -- formal_param = [ 'var' | 'const' | 'out' ] ident_list ':' [ 'array' 'of' ] type [ '=' const_expr ] .
        parseFormalParam = function(self)
            local line = self:line()
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
                line = line,
                access = varaccess,
                ids = ids,
                isarray = isarray,
                subtype = subtype,
                value = value
            }
        end,

        -- type = id | string [ '[' const_expr ']' ] | 'array' [ '[' ordinal_type { ',' ordinal_type } ']' ] 'of' type | rec_type
        --      | 'set' 'of' ( ordinal_type | id ) | simple_type .
        parseType = function(self)
            local tk = self:token()

            if tk == '<id>' then
                return self:parseTypeId()
            elseif tk == 'string' then
                local line = self:line()

                self:match('string')
                local length

                if self:token() == '[' then
                    self:match('[')
                    length = self:parseConstExpr()
                    self:match(']')
                end

                return access.const {
                    type = 'stringtype',
                    line = line,
                    length = length
                }
            elseif tk == 'array' then
                -- ArrayType
                local line = self:line()

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
                    line = line,
                    subtype = subtype,
                    limits = limits
                }
            elseif tk == 'record' then
                -- RecType
                return self:parseRecType()
            elseif tk == 'set' then
                -- SetType
                local line = self:line()
                self:match('set')
                self:match('of')

                local subtype = self:lexeme()

                if self:token() == '<id>' then
                    self:match('<id>')
                else
                    subtype = self:parseOrdinalType()
                end

                return access.const {
                    type = 'set',
                    line = line,
                    subtype = subtype
                }
            elseif tk == 'procedure' or tk == 'function' then
                return self:parseProcedureType()
            else
                return self:parseSimpleType()
            end
        end,

        -- procedure_type = ( procedure_heading | function_heading ) [ 'of' 'object' ] .
        parseProcedureType = function(self)
            local line = self:line()
            local subtype

            if self:token() == 'procedure' then
                subtype = self:parseProcedureHeading(false)
            else
                subtype = self:parseFunctionHeading(false)
            end

            local ofObject = false

            if self:token() == 'of' then
                self:match('of')
                self:match('object')
                ofObject = true
            end

            return access.const {
                type = 'proctype',
                line = line,
                subtype = subtype,
                ofObject = ofObject
            }
        end,

        -- rec_type = 'record' [ '(' id ')' ] { field_list } 'end' .
        parseRecType = function(self)
            local line = self:line()
            local list = {}
            local super = false

            self:match('record')

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
                line = line,
                super = super,
                declarations = access.const(list)
            }
        end,

        -- simple_type = 'real48' | 'real' | 'single' | 'double' | 'extended' | 'currency' | 'comp' | ordinal_type .
        parseSimpleType = function(self)
            local tk = self:token()

            if tk == 'real48' or tk == 'real' or tk == 'single' or tk == 'double' or tk == 'extended' or tk == 'currency'
                or tk == 'comp' then
                -- RealType
                local line = self:line()
                self:match(tk)

                return access.const {
                    type = 'realtype',
                    line = line,
                    subtype = tk
                }
            else
                return self:parseOrdinalType()
            end
        end,

        -- ordinal_type = enumerated_type | 'shortint' | 'smallint' | 'integer' | 'byte' | 'longint' | 'int64' | 'word' | 'boolean'
        --              | 'char' | 'widechar' | 'longword' | 'pchar' | const_expr '..' const_expr .
        parseOrdinalType = function(self)
            local tk = self:token()

            if tk == '(' then
                -- EnumeratedType
                return self:parseEnumeratedType()
            elseif tk == 'shortint' or tk == 'smallint' or tk == 'integer' or tk == 'byte' or tk == 'longint' or tk == 'int64'
                or tk == 'word' or tk == 'boolean' or tk == 'char' or tk == 'widechar' or tk == 'longword' or tk == 'pchar' then
                -- OrdIdent
                local line = self:line()
                self:match(tk)

                return access.const {
                    type = 'ordident',
                    line = line,
                    subtype = tk
                }
            else
                -- SubrangeType
                local line = self:line()
                local min = self:parseConstExpr()
                self:match('..')

                return access.const {
                    type = 'subrange',
                    line = line,
                    min = min,
                    max = self:parseConstExpr()
                }
            end
        end,

        -- enumerated_type = '(' id [ '=' const_expr ] { ',' id [ '=' const_expr ] } ')' .
        parseEnumeratedType = function(self)
            local line = self:line()
            local list = {}

            self:match('(')

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
                    self:match(')')

                    return access.const {
                        type = 'enumerated',
                        line = line,
                        elements = access.const(list)
                    }
                end

                self:match(',')
            end
        end,

        -- restricted_type = 'class' [ '(' id ')' ] { const_section | type_section | var_section | exported_heading | field_list }
        --                   'end' .
        parseRestrictedType = function(self)
            local line = self:line()
            local list = {}
            local super

            self:match('class')

            -- ClassHeritage
            if self:token() == '(' then
                self:match('(')
                super = self:lexeme()
                self:match('<id>')
                self:match(')')
            end

            while true do
                local tk = self:token()

                if tk == 'const' then
                    list[#list + 1] = self:parseConstSection()
                elseif tk == 'type' then
                    list[#list + 1] = self:parseTypeSection()
                elseif tk == 'var' then
                    list[#list + 1] = self:parseVarSection()
                elseif tk == 'procedure' or tk == 'function' or tk == 'constructor' or tk == 'destructor' then
                    list[#list + 1] = self:parseClassMethodHeading()
                elseif tk == '<id>' then
                    list[#list + 1] = self:parseFieldList()
                elseif tk == 'private' or tk == 'protected' or tk == 'public' or tk == 'published' then
                    -- We don't do anything with it for now
                    self:match(tk)
                else
                    break
                end
            end

            self:match('end')

            return access.const {
                type = 'class',
                line = line,
                super = super,
                declarations = access.const(list)
            }
        end,

        parseClassMethodHeading = function(self)
            if self:token() == 'constructor' or self:token() == 'destructor' then
                local line = self:line()
                local type = self:token() == 'constructor' and 'consthead' or 'desthead'
                self:match(self:token())

                local id = self:parseQualId()
                local list = false

                if self:token() == '(' then
                    list = self:parseFormalParameters()
                end

                self:match(';')

                local virtual = self:token() == 'virtual'

                if virtual then
                    self:match('virtual')
                    self:match(';')
                end

                return access.const {
                    type = type,
                    line = line,
                    id = id,
                    parameters = list,
                    virtual = virtual
                }
            else
                return self:parseExportedHeading()
            end
        end,

        -- field_list = ident_list ':' type ';' .
        parseFieldList = function(self)
            local line = self:line()
            local ids = self:parseIdentList()
            self:match(':')
            local subtype = self:parseType()
            self:match(';')

            return access.const {
                type = 'field',
                line = line,
                subtype = subtype,
                ids = ids
            }
        end,

        -- type_id = id [ '.' id ] .
        parseTypeId = function(self)
            local line = self:line()
            local id = self:lexeme()
            local unitid

            self:match('<id>')

            if self:token() == '.' then
                unitid = id
                id = self:lexeme()
                self:match('<id>')
            end

            return access.const {
                type = 'typeid',
                line = line,
                id = id,
                unitid = unitid
            }
        end,

        -- qual_id = id { '.' id } .
        parseQualId = function(self)
            local line = self:line()
            local list = {self:lexeme()}

            self:match('<id>')

            while self:token() == '.' do
                self:match('.')
                list[#list + 1] = self:lexeme()
                self:match('<id>')
            end

            return access.const {
                type = 'qualid',
                line = line,
                id = list
            }
        end,

        -- var_section = 'var' { ident_list ':' type '=' const_expr ';' } .
        parseVarSection = function(self)
            local line = self:line()
            local list = {}

            self:match('var')

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
                    line = line,
                    subtype = subtype,
                    ids = ids,
                    value = value
                }

                self:match(';')
            end

            return access.const {
                type = 'variables',
                line = line,
                variables = access.const(list)
            }
        end,

        -- block = { const_section | var_section } compound_stmt .
        parseBlock = function(self)
            local line = self:line()
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
                line = line,
                declarations = access.const(list),
                statement = self:parseCompoundStmt()
            }
        end,

        -- compound_stmt = 'begin' [ stmt_list ] 'end' .
        parseCompoundStmt = function(self)
            local line = self:line()
            local list

            self:match('begin')

            if self:token() ~= 'end' then
                list = self:parseStmtList()
            end

            self:match('end')

            return access.const {
                type = 'compoundstmt',
                line = line,
                statements = access.const(list or {})
            }
        end,

        -- stmt_list = statement { ';' statement } .
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

        -- statement = compound_stmt | if_stmt | case_stmt | repeat_stmt | while_stmt | for_stmt | with_stmt
        --           | simple_statement | empty_stmt .
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
                return self:parseWithStmt()
            elseif tk == 'inherited' then
                local line = self:line()
                self:match('inherited')

                return access.const {
                    type = 'inherited',
                    line = line,
                    designator = self:parseDesignator()
                }
            elseif tk == '<id>' then
                return self:parseSimpleStatement()
            elseif tk == '<freeform>' then
                local stmt = {
                    type = 'asm',
                    line = self:line(),
                    self:lexeme()
                }

                self:match('<freeform>')
                return stmt
            else
                return access.const {
                    type = 'emptystmt',
                    line = self:line()
                }
            end
        end,

        -- if_stmt = 'if' expression 'then' statement [ 'else' statement ] .
        parseIfStmt = function(self)
            local line = self:line()

            self:match('if')
            local condition = self:parseExpression()
            self:match('then')
            local ontrue = self:parseStatement()
            local onfalse = false

            if self:token() == 'else' then
                self:match('else')
                onfalse = self:parseStatement()
            end

            return access.const {
                type = 'if',
                line = line,
                condition = condition,
                ontrue = ontrue,
                onfalse = onfalse
            }
        end,

        -- case_stmt = 'case' expression 'of' case_selector { ';' case_selector } [ 'else' statement ] [ ';' ] 'end' .
        parseCaseStmt = function(self)
            local line = self:line()

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
                line = line,
                selector = selector,
                selectors = access.const(list),
                otherwise = otherwise
            }
        end,

        -- case_selector = case_label { ',' case_label } ':' statement '.'
        parseCaseSelector = function(self)
            local list = {self:parseCaseLabel()}

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:parseCaseLabel()
            end

            self:match(':')

            return access.const {labels = list, body = self:parseStatement()}
        end,

        -- case_label = const_expr [ '..' const_expr ] .
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

        -- repeat_stmt = 'repeat' statement [ ';' ] 'until' expression .
        parseRepeatStmt = function(self)
            local line = self:line()

            self:match('repeat')
            local body = self:parseStatement()

            if self:token() == ';' then
                -- Not sure how to handle this, the grammar says that semicolons separate statement, not that they termintate them
                self:match(';')
            end

            self:match('until')

            return access.const {
                type = 'repeat',
                line = line,
                body = body,
                condition = self:parseExpression()
            }
        end,

        -- while_stmt = 'while' expression 'do' statement .
        parseWhileStmt = function(self)
            local line = self:line()

            self:match('while')
            local condition = self:parseExpression()
            self:match('do')

            return access.const {
                type = 'while',
                line = line,
                condition = condition,
                body = self:parseStatement()
            }
        end,

        -- for_stmt = 'for' qual_id ':=' expression ( 'to' | 'downto' ) expression 'do' statement .
        parseForStmt = function(self)
            local line = self:line()

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
                line = line,
                variable = variable,
                first = first,
                direction = direction,
                last = last,
                body = self:parseStatement()
            }
        end,

        -- with_stmt = 'with' ident_list 'do' statement .
        parseWithStmt = function(self)
            local line = self:line()
            self:match('with')
            local list = self:parseIdentList()
            self:match('do')

            return access.const {
                type = 'with',
                line = line,
                ids = list,
                body = self:parseStatement()
            }
        end,

        -- simple_statement = designator [ ':=' expression | '(' expr_list ')' ] .
        parseSimpleStatement = function(self)
            local line = self:line()
            local designator = self:parseDesignator()

            if self:token() == ':=' then
                self:match(':=')

                return access.const {
                    type = 'assignment',
                    line = line,
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
                    line = line,
                    designator = designator,
                    arguments = access.const(list or {})
                }
            end
        end
    }
end

return {
    tokenize = function(path, source)
        local ok, tokens = pcall(tokenize, path, source)

        if not ok then
            return nil, tokens
        end

        return tokens
    end,

    preprocess = function(path, source, macros)
        local ok, tokens = pcall(tokenize, path, source)

        if not ok then
            return nil, tokens
        end

        local ok, pp_source = pcall(preprocess, path, tokens)

        if not ok then
            return nil, pp_source
        end

        local pp_factory, err = load(pp_source)

        if not pp_factory then
            return nil, err
        end

        local ok, preprocessor = pcall(pp_factory)

        if not ok then
            return nil, preprocessor
        end

        local ok, new_source = pcall(preprocessor, macros)

        if not ok then
            return nil, new_source
        end

        return new_source
    end,

    parse = function(path, tokens)
        local ok, parser = pcall(newParser, path, tokens)

        if not ok then
            return nil, parser
        end

        local ast = parser:parse()
        --[[local ok, ast = pcall(parser.parse, parser)

        if not ok then
            return nil, ast
        end]]

        return ast
    end
}
