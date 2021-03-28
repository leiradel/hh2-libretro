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
            'longint', 'int64', 'word', 'boolean', 'char', 'widechar', 'longword', 'pchar',
            'div', 'mod', 'and', 'or', 'in', 'is',
            'unit', 'interface', 'uses', 'type', 'true', 'false', 'class', 'end', 'procedure', 'function', 'var', 'const', 'array',
            'initialization',
            'of', 'record', 'implementation', 'begin', 'not',
            'if', 'then', 'else', 'for', 'to', 'downto', 'do', 'while', 'case'
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
        until la.token ~= '<linecomment>' and la.token ~= '<blockcomment>' and la.token ~= '<blockdirective>'

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
            consts = {},
            types = {},
            vars = {},
            procedures = {},
            declarations = {}
        }

        if self:token() == 'uses' then
            interface.uses = self:parseUsesClause()
        end

        -- InterfaceDecl
        while true do
            if self:token() == 'const' then
                local list = self:parseConstSection()
                append(interface.consts, list)
                append(interface.declarations, list)
            elseif self:token() == 'type' then
                local list = self:parseTypeSection()
                append(interface.types, list)
                append(interface.declarations, list)
            elseif self:token() == 'var' then
                local list = self:parseVarSection()
                append(interface.vars, list)
                append(interface.declarations, list)
            elseif self:token() == 'procedure' or self:token() == 'function' then
                local heading = self:parseExportedHeading()
                interface.procedures[#interface.procedures + 1] = heading
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
            consts = {},
            types = {},
            vars = {},
            procedures = {},
            declarations = {}
        }

        if self:token() == 'uses' then
            implementation.uses = self:parseUsesClause()
        end

        while true do
            if self:token() == 'const' then
                local list = self:parseConstSection()
                append(implementation.consts, list)
                append(implementation.declarations, list)
            elseif self:token() == 'type' then
                local list =self:parseTypeSection()
                append(implementation.types, list)
                append(implementation.declarations, list)
            elseif self:token() == 'var' then
                local list = self:parseVarSection()
                append(implementation.vars, list)
                append(implementation.declarations, list)
            elseif self:token() == 'procedure' or self:token() == 'function' then
                local decl = self:parseProcedureDeclSection()
                implementation.procedures[#implementation.procedures + 1] = decl
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
        local type = pcall(self.parseRecordConstant, self)

        if type then
            return type
        end

        self.current = current
        type = pcall(self.parseArrayConstant, self)

        if type then
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
        local field = {type = 'field', id = self:lexeme()}
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
            expr = {type = 'literal', subtype = '<boolean>', value = ok}
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
            expr = {type = 'cast', type = self:parseTypeId()}
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
                designator = {type = 'field', id = self:lexeme(), struct = designator}
                self:match('<id>')
            elseif tk == '[' then
                self:match('[')
                designator = {type = 'index', indices = self:parseExprList(), array = designator}
                self:match(']')
            elseif tk == '(' then
                self:match('(')
                designator = {type = 'function', arguments = self:parseExprList(), func = designator}
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
        return list
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
        while self:token() == '<id>' do
            local type = {id = self:lexeme()}
            self:match('<id>')
            self:match('=')

            if self:token() == 'type' then
                self:match('type')
            end

            if self:token() == 'class' then
                type.decl = self:parseRestrictedType()
            else
                type.decl = self:parseType()
            end

            self:match(';')
            list[#list + 1] = type
        end

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
        end

        if heading.subtype == 'function' then
            self:match(':')

            if self:token() == 'string' then
                self.returnType = 'string'
                self:match()
            else
                self.returnType = self:parseSimpleType()
            end
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
        local list = {self:parseFormalParam()}

        while self:token() == ';' do
            self:match(';')
            list[#list + 1] = self:parseFormalParam()
        end

        self:match(')')
        return list
    end

    function parser:parseFormalParam()
        local access, isarray, subtype, value

        if self:token() == 'var' or self:token() == 'const' or self:token() == 'out' then
            access = self:token()
            self:match(self:token())
        end

        -- Parameter
        local list = self:parseIdentList()
        self:match(':')

        if self:token() == 'array' then
            isarray = true
            self:match('array')
            self:match('of')
        end

        subtype = self:parseType()

        if not isarray and self:token() == '=' then
            self:match('=')
            value = self:parseConstExpr()
        end

        for i = 1, #list do
            local id = list[i]

            list[i] = {
                type = 'param',
                access = access,
                isarray = isarray,
                subtype = subype,
                value = value,
                id = id
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
        local class = {consts = {}, types = {}, vars = {}, procedures = {}, functions = {}, fields = {}}

        -- ClassHeritage
        if self:token() == '(' then
            self:match('(')
            class.super = self:parseIdentList()
            self:match(')')
        end

        while true do
            if self:token() == 'const' then
                append(class.consts, self:parseConstSection())
            elseif self:token() == 'type' then
                append(class.types, self:parseTypeSection())
            elseif self:token() == 'var' then
                append(class.vars, self:parseVarSection())
            elseif self:token() == 'procedure' or self:token() == 'function' then
                class.procedures[#class.procedures + 1] = self:parseExportedHeading()
            elseif self:token() == '<id>' then
                append(class.fields, self:parseFieldList())
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
        local class = {consts = {}, types = {}, vars = {}, procedures = {}, functions = {}, fields = {}}

        -- ClassHeritage
        if self:token() == '(' then
            self:match('(')
            class.super = self:parseIdentList()
            self:match(')')
        end

        while true do
            if self:token() == 'const' then
                append(class.consts, self:parseConstSection())
            elseif self:token() == 'type' then
                append(class.types, self:parseTypeSection())
            elseif self:token() == 'var' then
                append(class.vars, self:parseVarSection())
            elseif self:token() == 'procedure' or self:token() == 'function' then
                class.procedures[#class.procedures + 1] = self:parseExportedHeading()
            elseif self:token() == '<id>' then
                append(class.fields, self:parseFieldList())
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
            local list = self:parseIdentList()
            self:match(':')
            local type = self:parseType()

            for i = 1, #list do
                local id = list[i]

                list[i] = {
                    type = 'var',
                    subtype = type,
                    id = id
                }
            end

            if #list == 1 and self:token() == '=' then
                self:match('=')
                list[1].value = self:parseConstExpr()
            end

            self:match(';')
        end

        return list
    end

    function parser:parseBlock()
        local block = {type = 'block', consts = {}, types = {}, vars = {}, procedures = {}, functions = {}}

        -- DeclSection
        while true do
            if self:token() == 'const' then
                append(block.consts, self:parseConstSection())
            elseif self:token() == 'type' then
                append(block.types, self:parseTypeSection())
            elseif self:token() == 'var' then
                append(block.vars, self:parseVarSection())
            elseif self:token() == 'procedure' or self:token() == 'function' then
                block.procedures[#block.procedures + 1] = self:parseProcedureDeclSection()
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
        return list
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

            return {type = 'call', designator = designator, arguments = list}
        end
    end

    return parser
end
