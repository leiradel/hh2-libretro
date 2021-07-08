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

        while tk ~= ')' do
            list[#list + 1] = self:parsePropertyValue()
            tk = self:token()
        end

        self:match(')')
        return {type = 'position', value = list}
    end

    return parser
end

local function out(format, ...)
    io.write(string.format(format, ...))
end

local function generateValue(value)
    if value.type == 'set' then
        local comma = ''
        out('[')

        for _, element in ipairs(value.value) do
            out('%s%s', comma, element)
            comma = ', '
        end

        out(']')
    elseif value.type == 'position' then
        out('(X: ')
        generateValue(value.value[1])
        out('; Y: ')
        generateValue(value.value[2])
        out(')')
    elseif value.type == 'number' then
        out('%s%s', value.negative and '-' or '', value.value)
    elseif value.type == 'data' then
        out('nil')
    else
        out('%s', value.value)
    end
end

local function generateObject(node, indent)
    local spaces = string.rep('    ', indent)

    out('%swith %s do\n', spaces, node.id)
    out('%sbegin\n', spaces)

    for _, prop in ipairs(node.properties) do
        if prop.value.type ~= 'position' and prop.value.type ~= 'data' then
            out('%s    %s := ', spaces, table.concat(prop.id, '.'))
            generateValue(prop.value)
            out(';\n')
        end
    end

    for _, child in ipairs(node.children) do
        out('\n')
        out('%s    %s := %s.Create;\n', spaces, child.id, child.type)
        generateObject(child, indent + 1)
    end

    out('%send;\n', spaces)
end

if #arg < 1 then
    io.stderr:write(string.format('Usage: %s <inputfile.dfm>...\n', arg[0]))
    os.exit(1)
end

local ast = {}

for i = 1, #arg do
    local parser = newDfmParser(arg[i])
    ast[i] = parser:parse()
end

out('unit dfm;\n\n')
out('interface\n\n')

do
    out('uses\n')
    out('    Classes, SysUtils, Controls, Dialogs, ExtCtrls, Forms, Graphics, Menus, Messages, StdCtrls')

    for i = 1, #arg do
        local unit = arg[i]:match('.*[/\\](.+)'):match('(.*)%..-')
        out(', %s', unit)
    end

    out(';\n\n')

    for i = 1, #ast do
        out('procedure Init%s(%s: %s);\n', ast[i].type, ast[i].id, ast[i].type)
    end

    out('\n')
end

out('implementation\n\n')

do
    for i = 1, #ast do
        out('procedure Init%s(%s: %s);\n', ast[i].type, ast[i].id, ast[i].type)
        out('begin\n')
        generateObject(ast[i], 1)
        out('end;\n')
    end

    out('\n')
end

out('end.\n')
