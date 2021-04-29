local ddlt = require 'ddlt'

local function fatal(path, line, format, ...)
    local location = string.format('%s:%u: ', path, line)
    local message = string.format(format, ...)
    error(string.format('%s%s', location, message))
    io.stderr:write(location, message, '\n')
    os.exit(1)
end

local function append(dest, source)
    for i = 1, #source do
        dest[#dest + 1] = source[i]
    end
end

local function dump(t, i)
    i = i or 0
    local s = string.rep('  ', i)

    for k, v in pairs(t) do
        local z = type(v)

        if z == 'table' then
            print(string.format('%s%s', s, tostring(k)))
            dump(v, i + 1)
        else
            print(string.format('%s%s = %s', s, tostring(k), tostring(v)))
        end
    end
end

local function newDfmParser(path)
    -- https://www.davidghoyle.co.uk/WordPress/?page_id=1391

    local input, err = io.open(path, 'r')

    if not input then
        fatal(path, 0, 'Error opening input file: %s', err)
    end

    local source = input:read('*a')
    input:close()

    local lexer = ddlt.newLexer{
        source = source,
        file = path,
        language = 'pas',
        symbols = {':', '=', '<', '>', '[', ']', '(', ')', ',', '.', '-'},
        keywords = {'object', 'end', 'item', 'true', 'false'}
    }

    local tokens = {}
    local la

    repeat
        repeat
            local err
            la, err = lexer:next({})

            if not la then
                io.stderr:write(err)
                os.exit(1)
            end

            if la.token == '<blockcomment>' then
                -- dfm files use block comments for binary data
                la.token = '<data>'
            end
        until la.token ~= '<linecomment>' and la.token ~= '<blockdirective>'

        tokens[#tokens + 1] = la
    until la.token == '<eof>'

    local parser = {
        tokens = tokens,
        current = 1
    }

    function parser:error(line, format, ...)
        fatal(path, line, format, ...)
    end

    function parser:token(offset)
        return self.tokens[self.current + (offset or 0)].token
    end

    function parser:lexeme(offset)
        return self.tokens[self.current + (offset or 0)].lexeme
    end

    function parser:line(offset)
        return self.tokens[self.current + (offset or 0)].line
    end

    function parser:match(token)
        if token ~= self:token() then
            self:error(self:line(), '"%s" expected, found "%s"', token, self:token())
        end

        self.current = self.current + 1
    end

    function parser:parse()
        local ast = self:parseGoal()
        self:match('<eof>')
        return ast
    end

    function parser:parseGoal()
        return self:parseObject()
    end

    function parser:parseObject()
        self:match('object')
        local object = {type = 'object', id = self:lexeme(), children = {}, properties = {}}
        self:match('<id>')
        self:match(':')
        object.type = self:lexeme()
        self:match('<id>')

        if self:token() == '[' then
            self:match('[')
            object.index = self:parseNumber()
            self:match(']')
        end

        while self:token() ~= 'end' do
            if self:token() == 'object' then
                object.children[#object.children + 1] = self:parseObject()
            elseif self:token() == '<id>' then
                object.properties[#object.properties + 1] = self:parseProperty()
            else
                self:error(self:line(), '"object" or "<id>" expected, "%s" found', self:token())
            end
        end

        self:match('end')
        return object
    end

    function parser:parseNumber()
        local negative = self:token() == '-'

        if negative then
            self:match('-')
        end

        local tk = self:token()

        if tk == '<binary>' or tk == '<octal>' or tk == '<decimal>' or tk == '<hexadecimal>' or tk == '<float>' then
            local value = self:lexeme()
            self:match(tk)
            return {type = 'number', subtype = tk, value = value, negative = negative}
        else
            self:error(self:line(), '"<number>" expected, "%s" found', self:token())
        end
    end

    function parser:parseProperty()
        -- QualifiedIdent
        local id = {self:lexeme()}
        self:match('<id>')

        while self:token() == '.' do
            self:match('.')
            id[#id + 1] = self:lexeme()
            self:match('<id>')
        end

        self:match('=')
        return {id = id, value = self:parsePropertyValue()}
    end

    function parser:parsePropertyValue()
        local tk = self:token()

        if tk == '<id>' then
            local value = self:lexeme()
            self:match('<id>')
            return {type = 'id', value = value}
        elseif tk == '<string>' then
            local value = self:lexeme()
            self:match('<string>')
            return {type = 'string', value = value}
        elseif tk == '<binary>' or tk == '<octal>' or tk == '<decimal>' or tk == '<hexadecimal>' or tk == '<float>'
            or tk == '-' then
            return self:parseNumber()
        elseif tk == 'true' or tk == 'false' then
            local value = self:lexeme()
            self:match(tk)
            return {type = 'boolean', value = value}
        elseif tk == '[' then
            return self:parseSet()
        elseif tk == '<' then
            return self:parseItemList()
        elseif tk == '(' then
            return self:parsePositionData()
        elseif tk == '<data>' then
            local value = self:lexeme()
            self:match('<data>')
            return {type = 'data', value = value}
        else
            self:error(self:line(), '"<value>" expected, "%s" found', self:token())
        end
    end

    function parser:parseSet()
        self:match('[')
        local list = {}

        if self:token() == '<id>' then
            -- IdentList
            list[#list + 1] = self:lexeme()
            self:match('<id>')

            while self:token() == ',' do
                self:match(',')
                list[#list + 1] = self:lexeme()
                self:match('<id>')
            end
        end

        self:match(']')
        return {type = 'set', value = list}
    end

    function parser:parseItemList()
        self:match('<')
        local list = {}

        while self:token() == 'item' do
            self:match('item')
            local properties = {}

            while self:token() == '<id>' do
                properties[#properties + 1] = self:parseProperty()
            end

            self:match('end')
            list[#list + 1] = properties
        end

        self:match('>')
        return {type = 'items', value = list}
    end

    function parser:parsePositionData()
        self:match('(')
        local list = {}
        local tk = self:token()

        while tk == '<binary>' or tk == '<octal>' or tk == '<decimal>' or tk == '<hexadecimal>' or tk == '<float>' or tk == '-' do
            list[#list + 1] = self:parseNumber()
            tk = self:token()
        end

        self:match(')')
        return {type = 'position', value = list}
    end

    return parser
end

local function newParser(path)
    -- http://www.davidghoyle.co.uk/WordPress/?page_id=1389

    local input, err = io.open(path, 'r')

    if not input then
        fatal(path, 0, 'Error opening input file: %s', err)
    end

    local source = input:read('*a')
    input:close()

    local lexer = ddlt.newLexer{
        source = source,
        file = path,
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

    local tokens = {}
    local la

    repeat
        repeat
            local err
            la, err = lexer:next({})

            if not la then
                io.stderr:write(err)
                os.exit(1)
            end
        until la.token ~= '<linecomment>' and la.token ~= '<blockcomment>'

        tokens[#tokens + 1] = la
    until la.token == '<eof>'

    do
        local function getDirective(lexeme)
            lexeme = lexeme:lower()
            local directive, id = lexeme:match('{%$%s-([^%s]+)%s+(.+)%s-}')

            if directive then
                return directive, id
            end

            directive, id = lexeme:match('%(%*%$%s-([^%s]+)%s+(.+)%s-%*%)')

            if directive then
                return directive, id
            end

            directive = lexeme:match('{%$%s-(.+)%s-}')

            if directive then
                return directive
            end

            directive = lexeme:match('%(%*%$%s-(.+)%s-%*%)')
            return directive
        end

        local function findEndif(tokens, start)
            for i = start, #tokens do
                local directive, id = getDirective(tokens[i].lexeme)


                if directive == 'endif' and id == 'hh2' then
                    return i
                end
            end
        end

        local newTokens = {}
        local i = 1
        local count = #tokens

        while i <= count do
            if tokens[i].token == '<blockdirective>' then
                local directive, id = getDirective(tokens[i].lexeme)
                i = i + 1

                if id == 'hh2' then
                    if directive == 'ifdef' then
                        local j = findEndif(tokens, i) - 1

                        while i <= j do
                            newTokens[#newTokens + 1] = tokens[i]
                            i = i + 1
                        end

                        i = i + 1
                    elseif directive == 'ifndef' then
                        i = findEndif(tokens, i) + 1
                    end
                end
            else
                newTokens[#newTokens + 1] = tokens[i]
                i = i + 1
            end
        end

        tokens = newTokens
    end

    local parser = {
        tokens = tokens,
        current = 1
    }

    function parser:error(line, format, ...)
        fatal(path, line, format, ...)
    end

    function parser:token(offset)
        return self.tokens[self.current + (offset or 0)].token
    end

    function parser:lexeme(offset)
        return self.tokens[self.current + (offset or 0)].lexeme
    end

    function parser:line(offset)
        return self.tokens[self.current + (offset or 0)].line
    end

    function parser:match(token)
        if token ~= self:token() then
            self:error(self:line(), '"%s" expected, found "%s"', token, self:token())
        end

        self.current = self.current + 1
    end

    function parser:parse()
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
    end

    function parser:parseProgram()
        self:error(self:line(), 'Only units are supported')
    end

    function parser:parseUnit()
        self:match('unit');

        local unit = {type = 'unit', id = self:lexeme()}
        self:match('<id>')
        self:match(';')

        unit.interface = self:parseInterfaceSection()
        unit.implementation = self:parseImplementationSection()
        unit.initialization = self:parseInitSection()

        self:match('.')
        return unit
    end

    function parser:parseInterfaceSection()
        self:match('interface')

        local interface = {
            type = 'interface',
            uses = {},
            declarations = {}
        }

        if self:token() == 'uses' then
            interface.uses = self:parseUsesClause()
        end

        -- InterfaceDecl
        while true do
            if self:token() == 'const' then
                local list = self:parseConstSection()
                append(interface.declarations, list)
            elseif self:token() == 'type' then
                local list = self:parseTypeSection()
                append(interface.declarations, list)
            elseif self:token() == 'var' then
                local list = self:parseVarSection()
                append(interface.declarations, list)
            elseif self:token() == 'procedure' or self:token() == 'function' then
                local heading = self:parseExportedHeading()
                interface.declarations[#interface.declarations + 1] = heading
            else
                break
            end
        end

        return interface
    end

    function parser:parseImplementationSection()
        self:match('implementation')

        local implementation = {
            type = 'implementation',
            uses = {},
            declarations = {}
        }

        if self:token() == 'uses' then
            implementation.uses = self:parseUsesClause()
        end

        while true do
            if self:token() == 'const' then
                local list = self:parseConstSection()
                append(implementation.declarations, list)
            elseif self:token() == 'type' then
                local list =self:parseTypeSection()
                append(implementation.declarations, list)
            elseif self:token() == 'var' then
                local list = self:parseVarSection()
                append(implementation.declarations, list)
            elseif self:token() == 'procedure' or self:token() == 'function' then
                local decl = self:parseProcedureDeclSection()
                implementation.declarations[#implementation.declarations + 1] = decl
            else
                break
            end
        end

        return implementation
    end

    function parser:parseInitSection()
        if self:token() == 'initialization' then
            self:match('initialization')
            local list self:parseStmtList()
            self:match('end')
            return list
        elseif self:token() == 'begin' then
            self:match('begin')
            local list = self:parseStmtList()
            self:match('end')
            return list
        else
            self:match('end')
        end
    end

    function parser:parseUsesClause()
        self:match('uses')
        local list = self:parseIdentList()
        self:match(';')
        return list
    end

    function parser:parseIdentList()
        local list = {self:lexeme()}
        self:match('<id>')

        while self:token() == ',' do
            self:match(',')
            list[#list + 1] = self:lexeme()
            self:match('<id>')
        end

        return list
    end

    function parser:parseConstSection()
        self:match('const')
        local list = {}

        -- ConstantDecl
        while self:token() == '<id>' do
            local const = {type = 'const', id = self:lexeme()}
            self:match('<id>')

            if self:token() == '=' then
                self:match('=')
                const.value = self:parseConstExpr()
            elseif self:token() == ':' then
                self:match(':')
                const.subtype = self:parseType()
                self:match('=')
                const.value = self:parseTypedConstant()
            else
                self:error(self:line(), '"=" or ":" expected, found "%s"', self:token())
            end

            self:match(';')
            list[#list + 1] = const
        end

        return list
    end

    function parser:parseConstExpr()
        return self:parseExpression()
    end

    function parser:parseTypedConstant()
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
    end

    function parser:parseArrayConstant()
        self:match('(')
        local list = {self:parseTypedConstant()}

        while self:token() == ',' do
            self:match(',')
            list[#list + 1] = self:parseTypedConstant()
        end

        self:match(')')
        return {type = 'arrayconst', value = list}
    end

    function parser:parseRecordConstant()
        self:match('(')
        local list = {self:parseRecordFieldConstant()}

        while self:token() == ';' do
            self:match(';')
            list[#list + 1] = self:parseRecordFieldConstant()
        end

        self:match(')')
        return {type = 'recordconst', value = list}
    end

    function parser:parseRecordFieldConstant()
        local field = {type = 'recfield', id = self:lexeme()}
        self:match('<id>')
        self:match(':')
        field.value = self:parseTypedConstant()
        return field
    end

    function parser:parseExpression()
        local expr = self:parseSimpleExpression()
        local tk = self:token()

        while tk == '>' or tk == '<' or tk == '<=' or tk == '>=' or tk == '<>' or tk == 'in' or tk == 'is' or tk == '=' do
            expr = {type = tk, left = expr}
            self:match(tk)
            expr.right = self:parseSimpleExpression()
            tk = self:token()
        end

        return expr
    end

    function parser:parseSimpleExpression()
        local expr

        if self:token() == '+' then
            self:match('+')
            expr = self:parseTerm()
        elseif self:token() == '-' then
            expr = {type = 'unm'}
            self:match('-')
            expr.operand = self:parseTerm()
        else
            expr = self:parseTerm()
        end

        local tk = self:token()

        while tk == '+' or tk == '-' or tk == 'or' or tk == 'xor' do
            expr = {type = tk, left = expr}
            self:match(tk)
            expr.right = self:parseTerm()
            tk = self:token()
        end

        return expr
    end

    function parser:parseTerm()
        local expr = self:parseFactor()
        local tk = self:token()

        while tk == '*' or tk == '/' or tk == 'div' or tk == 'mod' or tk == 'and' or tk == 'shl' or tk == 'shr' do
            expr = {type = tk, left = expr}
            self:match(tk)
            expr.right = self:parseFactor()
            tk = self:token()
        end

        return expr
    end

    function parser:parseFactor()
        local tk = self:token()
        local expr

        if tk == '<id>' then
            expr = self:parseDesignator()

            if self:token() == '(' then
                self:match('(')
                expr.exprList = self:parseExprList()
                self:match(')')
            end
        elseif tk == 'true' or tk == 'false' then
            expr = {type = 'literal', subtype = 'boolean', value = tk}
            self:match(tk)
        elseif tk == '<decimal>' or tk == '<binary>' or tk == '<octal>' or tk == '<hexadecimal>' or tk == '<float>' then
            expr = {type = 'literal', subtype = tk, value = self:lexeme()}
            self:match(tk)
        elseif tk == '<string>' or tk == 'nil' then
            expr = {type = 'literal', subtype = tk, value = self:lexeme()}
            self:match(tk)
        elseif tk == '(' then
            self:match(tk)
            expr = self:parseExpression()
            self:match(')')
        elseif tk == 'not' then
            self:match(tk)
            expr = {type = 'not', operand = self:parseFactor()}
        elseif tk == '[' then
            expr = self:parseSetConstructor()
        else
            expr = {type = 'cast', type = self:parseOrdinalType()}
            self:match('(')
            expr.operand = self:parseExpression()
            self:match(')')
        end

        return expr
    end

    function parser:parseDesignator()
        local designator = {type = 'variable', qid = self:parseQualId()}
        local tk = self:token()

        while tk == '.' or tk == '[' or tk == '(' do
            -- DesignatorSubElement
            if tk == '.' then
                self:match('.')
                designator = {type = 'accfield', id = self:lexeme(), designator = designator}
                self:match('<id>')
            elseif tk == '[' then
                self:match('[')
                designator = {type = 'accindex', indices = self:parseExprList(), designator = designator}
                self:match(']')
            elseif tk == '(' then
                self:match('(')
                designator = {type = 'call', arguments = self:parseExprList(), designator = designator}
                self:match(')')
            end

            tk = self:token()
        end

        return designator
    end

    function parser:parseExprList()
        local list = {self:parseExpression()}

        while self:token() == ',' do
            self:match(',')
            list[#list + 1] = self:parseExpression()
        end

        return list
    end

    function parser:parseSetConstructor()
        self:match('[')
        local list = {self:parseSetElement()}

        while self:token() == ',' do
            self:match(',')
            list[#list + 1] = self:parseSetElement()
        end

        self:match(']')
        return {type = 'literal', subtype = 'set', elements = list}
    end

    function parser:parseSetElement()
        local element = {first = self:parseExpression()}

        if self:token() == '..' then
            self:match('..')
            element.last = self:parseExpression()
        end

        return element
    end

    function parser:parseTypeSection()
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
            list[#list + 1] = {id = id, type = 'type', subtype = type}
        until self:token() ~= '<id>'

        return list
    end

    function parser:parseExportedHeading()
        local heading = {type = 'heading', subtype = self:token()}

        if self:token() ~= 'procedure' and self:token() ~= 'function' then
            self:error(self:line(), '"procedure" or "function" expected, "%s" found', self:token())
        end

        self:match(self:token())
        heading.id = self:parseQualId()

        if self:token() == '(' then
            heading.paramList = self:parseFormalParameters()
        else
            heading.paramList = {}
        end

        if heading.subtype == 'function' then
            self:match(':')
            self.returnType = self:parseType()
        end

        self:match(';')
        return heading
    end

    function parser:parseProcedureDeclSection()
        local decl = self:parseExportedHeading()
        decl.type = 'decl'
        decl.block = self:parseBlock()
        self:match(';')
        return decl
    end

    function parser:parseFormalParameters()
        self:match('(')
        local list = self:parseFormalParam()

        while self:token() == ';' do
            self:match(';')
            append(list, self:parseFormalParam())
        end

        self:match(')')
        return list
    end

    function parser:parseFormalParam()
        local access, isarray, value

        if self:token() == 'var' or self:token() == 'const' or self:token() == 'out' then
            access = self:token()
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

        local list = {}

        for i = 1, #ids do
            list[#list + 1] = {
                type = 'param',
                access = access,
                isarray = isarray,
                subtype = subtype,
                value = value,
                id = ids[i]
            }
        end

        return list
    end

    function parser:parseType()
        local tk = self:token()

        if tk == '<id>' then
            return self:parseTypeId()
        elseif tk == 'string' then
            self:match('string')
            local type = {type = 'stringtype'}

            if self:token() == '[' then
                self:match('[')
                type.length = self:parseConstExpr()
                self:match(']')
            end

            return type
        elseif tk == 'array' then
            -- ArrayType
            self:match('array')
            local type = {type = 'arraytype'}

            if self:token() == '[' then
                self:match('[')
                local limits = {self:parseOrdinalType()}

                while self:token() == ',' do
                    self:match(',')
                    limits[#limits + 1] = self:parseOrdinalType()
                end

                self:match(']')
                type.limits = limits
            end

            self:match('of')
            type.subtype = self:parseType()
            return type
        elseif tk == 'record' then
            -- RecType
            return self:parseRecType()
        else
            return self:parseSimpleType()
        end
    end

    function parser:parseRecType()
        self:match('record')
        local class = {type = 'rectype', declarations = {}}

        -- ClassHeritage
        if self:token() == '(' then
            self:match('(')
            class.super = self:lexeme()
            self:match('<id>')
            self:match(')')
        end

        while true do
            if self:token() == '<id>' then
                append(class.declarations, self:parseFieldList())
            else
                break
            end
        end

        self:match('end')
        return class
    end

    function parser:parseSimpleType()
        local tk = self:token()

        if tk == 'real48' or tk == 'real' or tk == 'single' or tk == 'double' or tk == 'extended' or tk == 'currency'
            -- RealType
            or tk == 'comp' then
            self:match(tk)
            return {type = 'realtype', subtype = tk}
        else
            return self:parseOrdinalType()
        end
    end

    function parser:parseOrdinalType()
        local tk = self:token()

        if tk == '(' then
            -- EnumeratedType
            return self:parseEnumeratedType()
        elseif tk == 'shortint' or tk == 'smallint' or tk == 'integer' or tk == 'byte' or tk == 'longint' or tk == 'int64'
            or tk == 'word' or tk == 'boolean' or tk == 'char' or tk == 'widechar' or tk == 'longword' or tk == 'pchar' then
            -- OrdIdent
            self:match(tk)
            return {type = 'ordident', subtype = tk}
        else
            -- SubrangeType
            local min = self:parseConstExpr()
            self:match('..')
            return {type = 'subrange', min = min, max = self:parseConstExpr()}
        end
    end

    function parser:parseEnumeratedType()
        self:match('(')
        local list = {}

        -- EnumerateTypeElement
        while true do
            local element = {id = self:lexeme()}
            self:match('<id>')

            if self:token() == '=' then
                self:match('=')
                element.value = self:parseConstExpr()
            end

            list[#list + 1] = element

            if self:token() ~= ',' then
                return list
            end

            self:match(',')
        end
    end

    function parser:parseRestrictedType()
        self:match('class')
        local class = {type = 'class', declarations = {}}

        -- ClassHeritage
        if self:token() == '(' then
            self:match('(')
            class.super = self:lexeme()
            self:match('<id>')
            self:match(')')
        end

        while true do
            if self:token() == 'const' then
                append(class.declarations, self:parseConstSection())
            elseif self:token() == 'type' then
                append(class.declarations, self:parseTypeSection())
            elseif self:token() == 'var' then
                append(class.declarations, self:parseVarSection())
            elseif self:token() == 'procedure' or self:token() == 'function' then
                class.declarations[#class.declarations + 1] = self:parseExportedHeading()
            elseif self:token() == '<id>' then
                append(class.declarations, self:parseFieldList())
            else
                break
            end
        end

        self:match('end')
        return class
    end

    function parser:parseFieldList()
        local list = self:parseIdentList()
        self:match(':')
        local type = self:parseType()
        self:match(';')

        for i = 1, #list do
            local id = list[i]

            list[i] = {
                type = 'field',
                subtype = type,
                id = id
            }
        end

        return list
    end

    function parser:parseTypeId()
        local type = {type = 'typeid', id = self:lexeme()}
        self:match('<id>')

        if self:token() == '.' then
            self.unitid = self.id
            self.id = self:lexeme()
            self:match('<id>')
        end

        return type
    end

    function parser:parseQualId()
        local list = {self:lexeme()}
        self:match('<id>')

        while self:token() == '.' do
            self:match('.')
            list[#list + 1] = self:lexeme()
            self:match('<id>')
        end

        return {type = 'qualid', id = list}
    end

    function parser:parseVarSection()
        self:match('var')
        local list = {}

        -- VarDecl
        while self:token() == '<id>' do
            local ids = self:parseIdentList()
            self:match(':')
            local type = self:parseType()

            for i = 1, #ids do
                local id = ids[i]

                list[#list + 1] = {
                    type = 'var',
                    subtype = type,
                    id = id
                }
            end

            if #ids == 1 and self:token() == '=' then
                self:match('=')
                list[#list].value = self:parseConstExpr()
            end

            self:match(';')
        end

        return list
    end

    function parser:parseBlock()
        local block = {type = 'block', declarations = {}}

        -- DeclSection
        while true do
            if self:token() == 'const' then
                append(block.declarations, self:parseConstSection())
            elseif self:token() == 'var' then
                append(block.declarations, self:parseVarSection())
            else
                break
            end
        end

        block.statement = self:parseCompoundStmt()
        return block
    end

    function parser:parseCompoundStmt()
        self:match('begin')
        local list

        if self:token() ~= 'end' then
            list = self:parseStmtList()
        else
            list = {}
        end

        self:match('end')
        return {type = 'compoundstmt', statements = list}
    end

    function parser:parseStmtList()
        local list = {self:parseStatement()}

        while self:token() == ';' do
            self:match(';')

            if self:token() == 'end' then
                break
            end

            list[#list + 1] = self:parseStatement()
        end

        return list
    end

    function parser:parseStatement()
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
        elseif tk == '<id>' then
            return self:parseSimpleStatement()
        else
            return {type = 'emptystmt'}
        end
    end

    function parser:parseIfStmt()
        self:match('if')
        local statement = {type = 'if', condition = self:parseExpression()}
        self:match('then')
        statement.ontrue = self:parseStatement()

        if self:token() == 'else' then
            self:match('else')
            statement.onfalse = self:parseStatement()
        end

        return statement
    end

    function parser:parseCaseStmt()
        self:match('case')
        local statement = {type = 'case', selector = self:parseExpression()}
        self:match('of')

        local list = {self:parseCaseSelector()}

        while self:token() == ';' do
            self:match(';')

            if self:token() == 'end' then
                break
            end

            list[#list + 1] = self:parseCaseSelector()
        end

        statement.selectors = list

        if self:token() == 'else' then
            self:match('else')
            statement.otherwise = self:parseStatement()
        end

        if self:token() == ';' then
            self:match(';')
        end

        self:match('end')
        return statement
    end

    function parser:parseCaseSelector()
        local list = {self:parseCaseLabel()}

        while self:token() == ',' do
            self:match(',')
            list[#list + 1] = self:parseCaseLabel()
        end

        self:match(':')
        return {labels = list, body = self:parseStatement()}
    end

    function parser:parseCaseLabel()
        local label = {value = self:parseConstExpr()}

        if self:token() == '..' then
            self:match('..')
            label.min = label.value
            label.value = nil
            label.max = self:parseConstExpr()
        end

        return label
    end

    function parser:parseRepeatStmt()
        self:match('repeat')
        local statement = {type = 'repeat', body = self:parseStatement()}

        if self:token() == ';' then
            -- Not sure how to handle this, the grammar says that semicolons separate statement, not that they termintate them
            self:match(';')
        end

        self:match('until')
        statement.condition = self:parseExpression()
        return statement
    end

    function parser:parseWhileStmt()
        self:match('while')
        local statement = {type = 'while', condition = self:parseExpression()}
        self:match('do')
        statement.body = self:parseStatement()
        return statement
    end

    function parser:parseForStmt()
        self:match('for')
        local statement = {type = 'for', variable = self:parseQualId()}
        self:match(':=')
        statement.first = self:parseExpression()

        if self:token() == 'to' then
            self:match('to')
            statement.direction = 'up'
        elseif self:token() == 'downto' then
            self:match('downto')
            statement.direction = 'down'
        else
            self:error(self:line(), '"to" or "downto" expected, found "%s"', self:token())
        end

        statement.last = self:parseExpression()
        self:match('do')
        statement.body = self:parseStatement()
        return statement
    end

    function parser:parseSimpleStatement()
        local designator = self:parseDesignator()

        if self:token() == ':=' then
            self:match(':=')
            return {type = 'assignment', designator = designator, value = self:parseExpression()}
        else
            local list

            if self:token() == '(' then
                self:match('(')
                list = self:parseExprList()
                self:match(')')
            end

            return {type = 'proccall', designator = designator, arguments = list or {}}
        end
    end

    return parser
end

local function createScopes()
    local scopes = {
        access = 'system.%s',
        symbols = {
            paramstr = true, chr = true, randomize = true, ord = true, odd = true, round = true, random = true, tdatetime = true
        }
    }
    
    scopes = {
        previous = scopes,
        access = 'hh2.%s',
        symbols = {poke = true}
   }
    
    scopes = {
        previous = scopes,
        access = 'sysutils.%s',
        symbols = {
            extractfilepath = true, fileexists = true, inttostr = true, includetrailingpathdelimiter = true, now = true,
            datetimetotimestamp = true, beep = true
        }
    }
    
    scopes = {
        previous = scopes,
        access = 'inifiles.%s',
        symbols = {tinifile = true}
    }
    
    scopes = {
        previous = scopes,
        access = 'forms.%s',
        symbols = {
            action = true,
            application = true,
            screen = true,
            cafree = true,
            poscreencenter = true,
            tform = {
                type = 'class',
                subtype = {
                    scope = {
                        access = 'self.%s',
                        symbols = {top = true, left = true, doublebuffered = true, position = true}
                    }
                }
            }
        }
    }

    scopes = {
        previous = scopes,
        access = 'dialogs.%s',
        symbols = {messagedlg = true, mterror = true, mbok = true}
    }

    scopes = {
        previous = scopes,
        access = 'extctrls.%s',
        symbols = {timage = true, ttimer = true}
    }

    scopes = {
        previous = scopes,
        access = 'stdctrls.%s',
        symbols = {tlabel = true, tlcenter = true}
    }

    scopes = {
        previous = scopes,
        access = 'controls.%s',
        symbols = {mbleft = true, crhandpoint = true, crdefault = true}
    }

    scopes = {
        previous = scopes,
        access = 'graphics.%s',
        symbols = {clwhite = true, clgray = true}
    }

    scopes = {
        previous = scopes,
        access = 'classes.%s',
        symbols = {ssleft = true}
    }

    scopes = {
        previous = scopes,
        access = 'menus.%s',
        symbols = {tpopupmenu = true, tmenuitem = true}
    }

    scopes = {
        previous = scopes,
        access = 'registry.%s',
        symbols = {treginifile = true}
    }

    scopes = {
        previous = scopes,
        access = 'shellapi.%s',
        symbols = {shellexecute = true, handle = true, sw_shownormal = true}
    }

    scopes = {
        previous = scopes,
        access = 'fmodtypes.%s',
        symbols = {pfsoundsample = true, fsound_free = true, fsound_all = true}
    }

    scopes = {
        previous = scopes,
        access = 'fmod.%s',
        symbols = {
            fsound_sample_load = true, fsound_sample_free = true, fsound_close = true, fsound_playsound = true,
            fsound_stopsound = true, fsound_2d = true
        }
    }

    scopes = {
        previous = scopes,
        access = '%s',
        symbols = {
            gfxinit = {
                type = 'class',
                subtype = {
                    scope = {
                        access = 'gfxinit.%s',
                        symbols = {gfx_game_init = true}
                    }
                }
            }
        }
    }

    return scopes
end

local function newGenerator(path, ast)
    local function caller()
        local info = debug.getinfo(3, 'nl')
        return '' --string.format('<%s(%d)>', info.name, info.currentline)
    end

    local indentLevel = 0
    local code = {}

    local function indent()
        indentLevel = indentLevel + 1
    end

    local function unindent()
        indentLevel = indentLevel - 1
    end

    local function spaces()
        assert(indentLevel >= 0)
        code[#code + 1] = string.rep('    ', indentLevel)
    end

    local function out(format, ...)
        code[#code + 1] = caller()
        code[#code + 1] = string.format(format, ...)
    end

    local function outln(format, ...)
        if format ~= nil then
            spaces()
            code[#code + 1] = caller()
            code[#code + 1] = string.format(format, ...)
            code[#code + 1] = '\n'
        else
            code[#code + 1] = '\n'
        end
    end

    local scopes = createScopes()

    local function error(line, format, ...)
        fatal(path, line, format, ...)
    end

    local function unhandled(node, type)
        dump(node)
        print('====>', type)
        error(0, 'Don\'t know how to generate node "%s"', type)
    end

    local function pushScope(scope)
        scope.previous = scopes
        scope.symbols = scope.symbols or {}
        scopes = scope
    end

    local function popScope()
        scopes = scopes.previous
    end

    local function declare(id, node)
        id = id:lower()
        scopes.symbols[id] = node
        out(scopes.declare, id)
    end

    local function access(id)
        id = id:lower()
        local scope = scopes

        while scope do
            if scope.symbols[id] then
                return out(scope.access, id)
            end

            scope = scope.previous
        end

        error(0, 'Unknown identifier "%s"', id)
    end

    local function find(id)
        id = id:lower()
        local scope = scopes

        while scope do
            if scope.symbols[id] then
                return scope.symbols[id]
            end

            scope = scope.previous
        end
    end

    local generateNode

    local function defaultValue(node)
        if node.type == 'ordident' then
            if node.subtype == 'boolean' then
                out('false')
            elseif node.subtype == 'char' or node.subtype == 'widechar' then
                out('\'\\0\'')
            elseif node.subtype == 'pchar' then
                out('nil')
            else
                out('0')
            end
        elseif node.type == 'realtype' then
            out('0')
        elseif node.type == 'stringtype' then
            out('""')
        elseif node.type == 'typeid' then
            access(node.id)
            out('()')
        elseif node.type == 'arraytype' then
            out('(function()')
            outln()
            indent()
            outln('local a1 = {}')

            for i = 1, #node.limits do
                local limit = node.limits[i]

                spaces()
                out('for i%d = ', i)
                generateNode(limit.min)
                out(', ')
                generateNode(limit.max)
                out(' do')
                outln()
                indent()

                if i < #node.limits then
                    outln('local a%d = {}', i + 1)
                    outln('a%d[i%d] = a%d', i, i, i + 1)
                else
                    spaces()
                    out('a%d[i%d] = ', i, i)
                    defaultValue(node.subtype)
                    outln()
                end
            end

            for i = #node.limits, 1, -1 do
                unindent()
                outln('end')
            end

            outln('return a1')
            unindent()
            spaces()
            out('end)()')
        elseif node.type == 'rectype' then
            out('{')

            for i, decl in ipairs(node.declarations) do
                if i ~= 1 then
                    out(', ')
                end

                if decl.type == 'field' then
                    out('%s = ', decl.id)
                    defaultValue(decl.subtype)
                end
            end

            out('}')
        else
            unhandled(node)
        end
    end

    local function generateUnaryOp(operator, operand)
        out('%s(', operator)
        generateNode(operand)
        out(')')
    end

    local function generateBinaryOp(operator, left, right)
        out('(')
        generateNode(left)
        out(') %s (', operator)
        generateNode(right)
        out(')')
    end

    local function generateUnit(node)
        outln('local M = {}')
        outln()

        generateNode(node.interface)
        generateNode(node.implementation)
        --self:generateInitialization(node.initialization)

        outln('return M')
    end

    local function generateInterface(node)
        pushScope {declare = 'M.%s', access = 'M.%s'}

        for _, unit in ipairs(node.uses) do
            outln('local %s = require \'%s\'', unit:lower(), unit:lower())
        end

        outln()

        for _, decl in ipairs(node.declarations) do
            generateNode(decl)
        end

        -- Do *not* pop the scope, the symbols are still visible in the next sections
    end

    local function generateType(node)
        if node.subtype.type == 'class' then
            local class = node.subtype

            declare(node.id, node)
            out(' = class.new(')

            if class.super then
                access(class.super)
            end

            out(')')
            outln()
            outln()

            access(node.id)
            outln('.new = function(self)')
            indent()

            class.scope = {declare = 'self.%s', access = 'self.%s', symbols = {self = true}}
            pushScope(class.scope)

            if class.super then
                spaces()
                access(class.super)
                out('.new(self)')
                outln()
            end

            for _, decl in ipairs(class.declarations) do
                generateNode(decl)
            end

            unindent()
            outln('end')
            outln()
            popScope()
        else
            unhandled(node.subtype)
        end
    end

    local function generateField(node)
        spaces()
        declare(node.id, node)
        out(' = ')

        if node.value then
            generateNode(node.value)
        else
            defaultValue(node.subtype)
        end

        outln()
    end

    local function generateHeading(node)
        -- Just to declare the methods in the class scope
        spaces()
        out('-- ')
        declare(table.concat(node.id.id, '.'), node)
        outln()
    end

    local function generateConst(node)
        if node.subtype == nil or node.subtype.type == 'ordident' then
            spaces()
            declare(node.id, node)
            out(' = ')
            generateNode(node.value)
            outln()
        elseif node.subtype.type == 'arraytype' then
            local limits = {}

            for _, limit in ipairs(node.subtype.limits) do
                if limit.min.type ~= 'literal' or limit.max.type ~= 'literal' then
                    error(0, 'Array limits are not constant')
                end

                limits[#limits + 1] = {
                    min = tonumber(limit.min.value),
                    max = tonumber(limit.max.value),
                    current = tonumber(limit.min.value)
                }
            end

            spaces()
            out(' = (function()', declare(node.id, node))
            outln()
            indent()
            outln('local a = {}')
            outln()

            local set = {}

            while true do
                local indices = {}

                for i, limit in ipairs(limits) do
                    indices[#indices + 1] = tostring(limit.current)

                    local j = table.concat(indices, '][')

                    if i ~= #limits and not set[j] then
                        outln('a[%s] = {}', j)
                        set[j] = true
                    end
                end

                local value = node.value.value

                for i = 1, #limits - 1 do
                    value = value[limits[i].current].value
                end

                spaces()
                out('a[%s] = ', table.concat(indices, ']['))
                generateNode(value[limits[#limits].current - limits[#limits].min + 1])
                out('\n')

                for i = #limits, 1, -1 do
                    limits[i].current = limits[i].current + 1

                    if limits[i].current <= limits[i].max then
                        break
                    end

                    limits[i].current = limits[i].min

                    if i == 1 then
                        goto out
                    end
                end
            end

            ::out::
            outln('return a')
            unindent()
            outln('end)()')
        else
            unhandled(node)
        end
    end

    local function generateLiteral(node)
        if node.subtype == '<string>' then
            local value = node.value
            value = value:gsub('^\'', '')
            value = value:gsub('\'$', '')
            value = value:gsub('\'\'', '\'')

            value = value:gsub('\'#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('\'#(%d+)', function(x) return string.char(tonumber(x)) end)

            out('%q', value)
        elseif node.subtype == 'boolean' then
            out('%s', node.value)
        elseif node.subtype == '<decimal>' then
            out('%d', tonumber(node.value:gsub('[^%d]', ''), 10))
        elseif node.subtype == '<binary>' then
            out('%d', tonumber(node.value:gsub('[^01]', ''), 2))
        elseif node.subtype == '<octal>' then
            out('%d', tonumber(node.value:gsub('[^01234567]', ''), 8))
        elseif node.subtype == '<hexadecimal>' then
            out('%d', tonumber(node.value:gsub('[^%x]', ''), 16))
        elseif node.subtype == '<float>' then
            out('%s', node.value)
        elseif node.subtype == 'nil' then
            out('nil')
        elseif node.subtype == 'set' then
            out('{')

            for i, element in ipairs(node.elements) do
                if i ~= 1 then
                    out(', ')
                end

                out('[')
                generateNode(element.first)
                out('] = true')
            end

            out('}')
        else
            unhandled(node)
        end
    end

    local function generateAddition(node)
        generateBinaryOp('+', node.left, node.right)
    end

    local function generateVariable(node)
        generateNode(node.qid)
    end

    local function generateQualid(node)
        if node.id[1]:lower() == 'true' then
            dump(node)
            error(0, '')
        end

        access(node.id[1]:lower())

        for i = 2, #node.id do
            out('.')
            out('%s', node.id[i]:lower())
        end
    end

    local function generateVar(node)
        spaces()
        declare(node.id, node)
        out(' = ')

        if node.value then
            generateNode(node.value)
        else
            defaultValue(node.subtype)
        end

        outln()
    end

    local function generateImplementation(node)
        pushScope {declare = 'local %s', access = '%s'}

        for _, unit in ipairs(node.uses) do
            outln('local %s = require \'%s\'', unit:lower(), unit:lower())
        end

        outln()

        for _, decl in ipairs(node.declarations) do
            generateNode(decl)
        end

        outln()
        -- Do *not* pop the scope, the symbols are still visible in the next sections
    end

    local function generateDecl(node)
        local scopeCount = 0
        spaces()
        generateNode(node.id)

        if #node.id.id ~= 1 then
            local lastId = node.id.id[#node.id.id]
            node.id.id[#node.id.id] = nil

            local className = table.concat(node.id.id, '.')
            node.id.id[#node.id.id + 1] = lastId

            local classNode = find(className)
            local super = classNode.subtype.super

            while super do
                local superNode = find(super)
                pushScope(superNode.subtype.scope)
                scopeCount = scopeCount + 1
                super = superNode.super
            end

            pushScope(classNode.subtype.scope)
            scopeCount = scopeCount + 1
        end

        out(' = function(')
        local symbols = {}

        for i, param in ipairs(node.paramList) do
            if i ~= 1 then
                out(', ')
            end

            out('%s', param.id:lower())
            symbols[param.id:lower()] = true
        end

        out(')')
        outln()
        indent()

        pushScope {declare = 'local %s', access = '%s', symbols = symbols}
        scopeCount = scopeCount + 1

        for _, decl in ipairs(node.block.declarations) do
            generateNode(decl)
        end

        generateNode(node.block.statement)

        for i = 1, scopeCount do
            popScope()
        end

        unindent()
        outln('end')
    end

    local function generateCompoundStmt(node)
        for _, statement in ipairs(node.statements) do
            generateNode(statement)
        end
    end

    local function generateAssignment(node)
        spaces()
        generateNode(node.designator)
        out(' = ')
        generateNode(node.value)
        outln()
    end

    local function generateUnaryMinus(node)
        generateUnaryOp('-', node.operand)
    end

    local function generateIf(node)
        spaces()
        out('if ')
        generateNode(node.condition)
        out(' then')
        outln()

        indent()
        generateNode(node.ontrue)
        unindent()

        if node.onfalse then
            outln('else')
            indent()
            generateNode(node.onfalse)
            unindent()
        end

        outln('end')
    end

    local function generateNot(node)
        generateUnaryOp('not', node.operand)
    end

    local function generateFor(node)
        spaces()
        out('for ')
        generateNode(node.variable)
        out(' = ')
        generateNode(node.first)
        out(', ')
        generateNode(node.last)
        out(', ')
        out('%d do', node.direction == 'up' and 1 or -1)
        outln()

        indent()
        generateNode(node.body)
        unindent()
        outln('end')
    end

    local function generateFieldAccess(node)
        generateNode(node.designator)
        out('.%s', node.id:lower())
    end

    local function generateIndexAccess(node)
        generateNode(node.designator)
        out('[')

        for i, index in ipairs(node.indices) do
            if i ~= 1 then
                out('][')
            end

            generateNode(index)
        end

        out(']')
    end

    local function generateCall(node)
        if #node.designator.qid.id == 1 and node.designator.qid.id[1]:lower() == 'dec' then
            -- Special case: dec
            generateNode(node.arguments[1])
            out(' = ')
            generateNode(node.arguments[1])
            out(' - ')

            if #node.arguments == 1 then
                out('1')
            else
                out('(')
                generateNode(node.arguments[2])
                out(')')
            end
        elseif #node.designator.qid.id == 1 and node.designator.qid.id[1]:lower() == 'inc' then
            -- Special case: inc
            generateNode(node.arguments[1])
            out(' = ')
            generateNode(node.arguments[1])
            out(' + ')

            if #node.arguments == 1 then
                out('1')
            else
                out('(')
                generateNode(node.arguments[2])
                out(')')
            end
        elseif #node.designator.qid.id == 1 and node.designator.qid.id[1]:lower() == 'decodetime' then
            -- Special case: decodetime
            for i = 2, 5 do
                if i ~= 2 then
                    out(', ')
                end

                generateNode(node.arguments[i])
            end

            out(' = sysutils.decodetime(')
            generateNode(node.arguments[1])
            out(')')
        else
            generateNode(node.designator)
            out('(')

            for i, arg in ipairs(node.arguments) do
                if i ~= 1 then
                    out(', ')
                end

                generateNode(arg)
            end

            out(')')
        end
    end

    local function generateProcedureCall(node)
        spaces()
        generateNode(node.designator)

        if node.designator.type == 'variable' or node.designator.type == 'accfield' then
            -- For procedure calls without an argument list inside parenthesis
            out('()')
        end

        outln()
    end

    local function generateMultiplication(node)
        generateBinaryOp('*', node.left, node.right)
    end

    local function generateGreaterThan(node)
        generateBinaryOp('>', node.left, node.right)
    end

    local function generateLessEqual(node)
        generateBinaryOp('<=', node.left, node.right)
    end

    local function generateRepeat(node)
        outln('repeat')
        indent()
        generateNode(node.body)
        unindent()

        spaces()
        out('until ')
        generateNode(node.condition)
        outln()
    end

    local function generateWhile(node)
        spaces()
        out('while ')
        generateNode(node.condition)
        out(' do')
        outln()

        indent()
        generateNode(node.body)
        unindent()
        outln('end')
    end

    local function generateGreaterEqual(node)
        generateBinaryOp('>=', node.left, node.right)
    end

    local function generateMod(node)
        generateBinaryOp('%', node.left, node.right)
    end

    local function generateDiv(node)
        generateBinaryOp('//', node.left, node.right)
    end

    local function generateCase(node)
        outln('do')
        indent()
        spaces()
        out('local _ = ')
        generateNode(node.selector)
        outln()

        for i, selector in ipairs(node.selectors) do
            spaces()

            if i == 1 then
                out('if ')
            else
                out('elseif ')
            end

            for j, label in ipairs(selector.labels) do
                if j ~= 1 then
                    out(' or ')
                end

                if label.value then
                    out('_ == (')
                    generateNode(label.value)
                    out(')')
                else
                    out('(_ >= (')
                    generateNode(label.min)
                    out(') and _ <= (')
                    generateNode(label.max)
                    out('))')
                end
            end

            out(' then')
            outln()
            indent()
            generateNode(selector.body)
            unindent()
        end

        if node.otherwise then
            indent()
            generateNode(node.otherwise)
            unindent()
        end

        outln('end')
        unindent()
        outln('end')
    end

    local function generateEqual(node)
        generateBinaryOp('==', node.left, node.right)
    end

    local function generateAnd(node)
        generateBinaryOp('and', node.left, node.right)
    end

    local function generateIn(node)
        generateNode(node.left)
        out('[')
        generateNode(node.right)
        out(']')
    end

    local function generateSubtract(node)
        generateBinaryOp('-', node.left, node.right)
    end

    local function generateOr(node)
        generateBinaryOp('or', node.left, node.right)
    end

    local function generateLessThan(node)
        generateBinaryOp('<', node.left, node.right)
    end

    local function generateDivide(node)
        generateBinaryOp('/', node.left, node.right)
    end

    local function generateNotEqual(node)
        generateBinaryOp('~=', node.left, node.right)
    end

    local function generateEmptyStatement(node)
    end

    local generators = {
        unit = generateUnit,
        interface = generateInterface,
        type = generateType,
        field = generateField,
        heading = generateHeading,
        const = generateConst,
        literal = generateLiteral,
        ['+'] = generateAddition,
        variable = generateVariable,
        qualid = generateQualid,
        var = generateVar,
        implementation = generateImplementation,
        decl = generateDecl,
        compoundstmt = generateCompoundStmt,
        assignment = generateAssignment,
        unm = generateUnaryMinus,
        ['if'] = generateIf,
        ['not'] = generateNot,
        ['for'] = generateFor,
        accfield = generateFieldAccess,
        accindex = generateIndexAccess,
        call = generateCall,
        proccall = generateProcedureCall,
        ['*'] = generateMultiplication,
        ['>'] = generateGreaterThan,
        ['<='] = generateLessEqual,
        ['repeat'] = generateRepeat,
        ['while'] = generateWhile,
        ['>='] = generateGreaterEqual,
        mod = generateMod,
        div = generateDiv,
        case = generateCase,
        ['='] = generateEqual,
        ['and'] = generateAnd,
        ['in'] = generateIn,
        ['-'] = generateSubtract,
        ['or'] = generateOr,
        ['<'] = generateLessThan,
        ['/'] = generateDivide,
        ['<>'] = generateNotEqual,
        emptystmt = generateEmptyStatement,
    }

    generateNode = function(node)
        --local info = debug.getinfo(2, 'nl')
        --out('--[[%s(%d):%s]]', info.name, info.currentline, node.type)

        local generator = generators[node.type]

        if generator then
            generator(node)
        else
            unhandled(node, node.type)
        end
    end

    return function()
        generateNode(ast)
        return table.concat(code, '')
    end
end

return {
    newParser = newParser,
    newDfmParser = newDfmParser,
    newGenerator = newGenerator
}
