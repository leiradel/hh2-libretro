-- Requires
local pascal = require 'pascal'
local ddlt = require 'ddlt'
local access = require 'access'

local function dump(tab, level)
    local spaces = string.rep('    ', level or 0)

    if not level then
        io.stderr:write('=======================================================\n')
    end

    for k, v in pairs(tab) do
        io.stderr:write(string.format('%s\t%s\n', tostring(k), tostring(v)))

        if level and type(v) == 'table' then
            dump(v, level + 1)
        end
    end

    if not level then
        io.stderr:write('-------------------------------------------------------\n')
    end
end

local cache = {}

local function parse(path, macros)
    assert(type(path) == 'string')
    assert(type(macros) == 'table')

    -- Use absolute path with the cache
    local abs_path = ddlt.realpath(path)

    -- Check the cache, assumes the same macros are always used
    local source = cache[abs_path]

    if source then
        return source
    end

    -- Load the source code from the file system
    local file, err = io.open(path, 'r')

    if not file then
        return nil, string.format('%s:0: Error opening input file: %s', path, err)
    end

    local source = file:read('*a')
    file:close()

    -- Pre-process the source code with the macros
    local new_source, err = pascal.preprocess(path, source, macros)

    if not new_source then
        return nil, err
    end

    -- Tokenized the pre-processed source code
    local tokens, err = pascal.tokenize(path, new_source)

    if not tokens then
        return nil, err
    end

    -- Parse the token stream
    local ast, err = pascal.parse(path, tokens)

    if not ast then
        return nil, err
    end

    -- We have an AST
    return ast
end

local function findUnit(unit, searchPaths)
    assert(type(unit) == 'string')
    assert(type(searchPaths) == 'table')

    unit = ddlt.join(nil, unit:lower(), 'pas')

    for i = 1, #searchPaths do
        for lower, entry in pairs(searchPaths[i]) do
            local dir, name, extension = ddlt.split(lower)
            local filename = ddlt.join(nil, name, extension)

            if filename == unit then
                return entry
            end
        end
    end

    return nil
end

local function generate(ast, searchPaths, macros, out)
    assert(type(ast) == 'userdata')
    assert(type(searchPaths) == 'table')
    assert(type(macros) == 'table')
    assert(type(out) == 'table')

    local defaultValues = {
        real48 = 0,
        real = 0,
        single = 0,
        double = 0,
        extended = 0,
        currency = 0,
        comp = 0,
        shortint = 0,
        smallint = 0,
        integer = 0,
        byte = 0,
        longint = 0,
        int64 = 0,
        word = 0,
        boolean = false,
        char = '"\0"',
        widechar = '"\0"',
        longword = 0,
        pchar = nil
    }

    local scope = false

    local function fatal(line, format, ...)
        error(string.format('%s:%u: %s', ast.path, line, string.format(format, ...)))
    end

    local function push(declareFmt, accessFmt)
        assert(declareFmt == nil or type(declareFmt) == 'string')
        assert(type(accessFmt) == 'string')

        local ids = {}

        local new_scope = access.const {
            ids = ids,
            declare = declareFmt or false,
            access = accessFmt,
            previous = scope
        }

        scope = new_scope
        return ids
    end

    local function findScope(id)
        assert(type(id) == 'string')

        id = id:lower()
        local current = scope

        while current do
            if current.ids[id] then
                return current
            end

            current = current.previous
        end
    end

    local function accessId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope and scope.access then
            return string.format(scope.access, id:lower())
        end
    end

    local function declareId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope and scope.declare then
            return string.format(scope.declare, id:lower())
        end
    end

    local function findId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope  then
            return scope.ids[id:lower()]
        end
    end

    local function iterateDeclarations(declarations, callback)
        for i = 1, #declarations do
            local decl = declarations[i]

            if decl.type == 'types' then
                for i = 1, #decl.types do
                    local type = decl.types[i]
                    local subtype = type.subtype

                    if subtype.type == 'enumerated' then
                        callback('enumerated', type.id, subtype)
                    elseif subtype.type == 'set' then
                        callback('set', type.id, subtype)
                    end
                end
            elseif decl.type == 'constants' then
                for i = 1, #decl.constants do
                    local const = decl.constants[i]
                    callback('constant', const.id, const)
                end
            elseif decl.type == 'variables' then
                for i = 1, #decl.variables do
                    local variable = decl.variables[i]
                    local subtype = variable.subtype

                    for j = 1, #variable.ids do
                        callback('variable', variable.ids[j], subtype)
                    end

                end
            elseif decl.type == 'procdecl' then
                callback('procdecl', decl.heading.qid.id, decl)
            elseif decl.type == 'prochead' or decl.type == 'funchead' or decl.type == 'consthead' or decl.type == 'desthead' then
                callback(decl.type, decl.qid.id, decl)
            elseif decl.type == 'field' then
                local subtype = decl.subtype

                for i = 1, #decl.ids do
                    callback('field', decl.ids[i], subtype)
                end
            else
                dump(decl)
                error(string.format('do not know how to push declaration %s', decl.type))
            end
        end
    end

    local function pushDeclarations(declarations, declareFmt, accessFmt)
        local ids = push(declareFmt, accessFmt)

        for i = 1, #declarations do
            local decl = declarations[i]

            if decl.type == 'types' then
                for i = 1, #decl.types do
                    local type = decl.types[i]
                    local subtype = type.subtype

                    ids[type.id:lower()] = subtype

                    if subtype.type == 'enumerated' then
                        for i = 1, #subtype.elements do
                            ids[subtype.elements[i].id:lower()] = subtype
                        end
                    elseif subtype.type == 'set' then
                        local subtype = subtype.subtype

                        if subtype then
                            for i = 1, #subtype.elements do
                                ids[subtype.elements[i].id:lower()] = subtype
                            end
                        end
                    end
                end
            elseif decl.type == 'constants' then
                for i = 1, #decl.constants do
                    local const = decl.constants[i]
                    ids[const.id:lower()] = const
                end
            elseif decl.type == 'variables' then
                for i = 1, #decl.variables do
                    local variable = decl.variables[i]
                    local subtype = variable.subtype

                    for j = 1, #variable.ids do
                        ids[variable.ids[j]:lower()] = subtype
                    end
                end
            elseif decl.type == 'procdecl' then
                if not findId(decl.heading.qid.id[1]) then
                    ids[table.concat(decl.heading.qid.id, '.'):lower()] = decl
                end
            elseif decl.type == 'prochead' or decl.type == 'funchead' or decl.type == 'consthead' or decl.type == 'desthead' then
                ids[table.concat(decl.qid.id, '.'):lower()] = decl
            elseif decl.type == 'field' then
                for i = 1, #decl.ids do
                    ids[decl.ids[i]:lower()] = decl.subtype
                end
            else
                dump(decl)
                error(string.format('do not know how to push declaration %s', decl.type))
            end
        end
    end

    local genExpression, genDesignator, genArray

    local function genLiteral(literal)
        assert(type(literal) == 'userdata')
        assert(literal.type == 'literal')

        if literal.subtype == '<decimal>' then
            out('%s', tostring(literal.value))
        elseif literal.subtype == '<hexadecimal>' then
            out('0x%s', tostring(literal.value:gsub('[^%x]', '')))
        elseif literal.subtype == '<float>' then
            out('%s', tostring(literal.value))
        elseif literal.subtype == '<string>' then
            local value = literal.value
            value = value:gsub('^\'', '')
            value = value:gsub('\'$', '')
            value = value:gsub('\'\'', '\'')

            value = value:gsub('\'#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('\'#(%d+)', function(x) return string.char(tonumber(x)) end)

            out('%q', value)
        elseif literal.subtype == 'boolean' then
            out('%s', tostring(literal.value))
        elseif literal.subtype == 'nil' then
            out('nil')
        elseif literal.subtype == 'set' then
            out('hh2rt.instantiateSet({')
            local comma = ''

            for i = 1, #literal.elements do
                local element = literal.elements[i]

                out(comma)
                comma = ', '

                if element.value then
                    genDesignator(element.value)
                else
                    dump(element)
                    error('do not know how to generate literal set element without a value')
                end
            end

            out('})')
        else
            dump(literal)
            error(string.format('do not know how to generate literal %s', literal.subtype))
        end
    end

    local function genDefaultValue(value)
        while value.type == 'typeid' do
            value = findId(value.id)
        end

        if value.type == 'enumerated' then
            out('%s', accessId(value.elements[1].id))
        elseif value.type == 'class' then
            out('nil')
            --out('%s.create()', accessId(subtype.id))
        elseif value.type == 'proctype' then
            out('function() end')
        elseif value.type == 'ordident' or value.type == 'realtype' then
            out('%s', defaultValues[value.subtype])
        --elseif value.type == 'subrange' then
        --    out('0')
        elseif value.type == 'set' then
            out('hh2rt.instantiateSet(%s)', accessId(value.id))
        elseif value.type == 'stringtype' then
            out('""')
        else
            dump(value)
            error(string.format('do not know how to initialize field %s', value.type))
        end
    end

    local function genConstValue(value)
        local function genValue(v)
            if type(v) ~= 'userdata' then
                out('%s', tostring(v))
            elseif #v ~= 0 then
                out('{')
                genValue(v[1])

                for i = 2, #v do
                    out(', ')
                    genValue(v[i])
                end

                out('}')
            elseif v.type == 'arrayconst' then
                out('\n')
                out:indent()
                genValue(v.value)
                out:unindent()
            else
                genLiteral(v)
            end
        end

        if value.type == 'arrayconst' then
            genValue(value.value)
        else
            genLiteral(value)
        end
    end

    genDesignator = function(designator)
        if designator.type == 'variable' then
            local acc = accessId(designator.qid.id[1])

            if not acc then
                fatal(designator.line, 'unknown identifier: %q', designator.qid.id[1])
            end

            out('%s', acc)

            for i = 2, #designator.qid.id do
                out('.%s', designator.qid.id[i]:lower())
            end

            if not designator.next then
                local t = findId(designator.qid.id[1])

                if type(t) == 'userdata' and t.type == 'funchead' then
                    out('()')
                end
            end
        elseif designator.type == 'accfield' then
            out('.%s', designator.id:lower())
        elseif designator.type == 'accindex' then
            out('[')
            genExpression(designator.indices[1])

            for i = 2, #designator.indices do
                out('][')
                genExpression(designator.indices[i])
            end

            out(']')
        elseif designator.type == 'call' then
            out('(')

            if designator.arguments then
                local comma = ''

                for i = 1, #designator.arguments do
                    out(comma)
                    comma = ', '

                    genExpression(designator.arguments[i])
                end
            end

            out(')')
        else
            dump(designator)
            error(string.format('do not know how to generate designator %s', designator.type))
        end

        if designator.next then
            genDesignator(designator.next)
        end
    end

    genExpression = function(expression)
        local function genNot(notop)
            out('(not ')
            genExpression(notop.operand)
            out(')')
        end

        local function genAdd(add)
            out('(')
            genExpression(add.left)
            out(' + ')
            genExpression(add.right)
            out(')')
        end

        local function genAnd(andop)
            out('(')
            genExpression(andop.left)
            out(' and ')
            genExpression(andop.right)
            out(')')
        end

        local function genNotEqual(ne)
            out('(')
            genExpression(ne.left)
            out(' ~= ')
            genExpression(ne.right)
            out(')')
        end

        local function genCast(cast)
            local subtype = cast.subtype

            if subtype.type == 'ordident' then
                if subtype.subtype == 'boolean' then
                    out('(')
                    genExpression(cast.operand)
                    out(') ~= 0')
                else
                    dump(cast)
                    dump(subtype)
                    error(string.format('do not know how to generate cast to %s', subtype.subtype))
                end
            else
                dump(cast)
                dump(subtype)
                error(string.format('do not know how to generate cast to %s', subtype.type))
            end
        end

        local function genDivide(divide)
            out('(')
            genExpression(divide.left)
            out(' / ')
            genExpression(divide.right)
            out(')')
        end

        local function genSubtract(subtract)
            out('(')
            genExpression(subtract.left)
            out(' - ')
            genExpression(subtract.right)
            out(')')
        end

        local function genDiv(div)
            out('(')
            genExpression(div.left)
            out(' // ')
            genExpression(div.right)
            out(')')
        end

        local function genEqual(ne)
            out('(')
            genExpression(ne.left)
            out(' == ')
            genExpression(ne.right)
            out(')')
        end

        local function genIn(inop)
            genExpression(inop.right)
            out('.containts(')
            genExpression(inop.left)
            out(')')
        end

        local function genGreaterThan(gt)
            out('(')
            genExpression(gt.left)
            out(' > ')
            genExpression(gt.right)
            out(')')
        end

        local function genGreaterEqual(node)
            out('(')
            genExpression(node.left)
            out(' >= ')
            genExpression(node.right)
            out(')')
        end

        local function genLessThan(lt)
            out('(')
            genExpression(lt.left)
            out(' < ')
            genExpression(lt.right)
            out(')')
        end

        local function genLessEqual(le)
            out('(')
            genExpression(le.left)
            out(' <= ')
            genExpression(le.right)
            out(')')
        end

        local function genUnaryMinus(minus)
            out('(-')
            genExpression(minus.operand)
            out(')')
        end

        local function genMultiply(multiply)
            out('(')
            genExpression(multiply.left)
            out(' * ')
            genExpression(multiply.right)
            out(')')
        end

        local function genModulus(node)
            out('(')
            genExpression(node.left)
            out(' %% ')
            genExpression(node.right)
            out(')')
        end

        local function genOr(node)
            out('(')
            genExpression(node.left)
            out(' or ')
            genExpression(node.right)
            out(')')
        end

        local type = expression.type

        if type == 'literal' then
            genLiteral(expression)
        elseif type == 'variable' or type == 'accfield' or type == 'accindex' or type == 'call' then
            genDesignator(expression)
        elseif type == 'not' then
            genNot(expression)
        elseif type == '+' then
            genAdd(expression)
        elseif type == 'and' then
            genAnd(expression)
        elseif type == '<>' then
            genNotEqual(expression)
        elseif type == 'cast' then
            genCast(expression)
        elseif type == '/' then
            genDivide(expression)
        elseif type == '-' then
            genSubtract(expression)
        elseif type == 'div' then
            genDiv(expression)
        elseif type == '=' then
            genEqual(expression)
        elseif type == 'in' then
            genIn(expression)
        elseif type == '>' then
            genGreaterThan(expression)
        elseif type == '>=' then
            genGreaterEqual(expression)
        elseif type == '<' then
            genLessThan(expression)
        elseif type == '<=' then
            genLessEqual(expression)
        elseif type == 'unm' then
            genUnaryMinus(expression)
        elseif type == '*' then
            genMultiply(expression)
        elseif type == 'mod' then
            genModulus(expression)
        elseif type == 'or' then
            genOr(expression)
        else
            dump(expression)
            error(string.format('do not know how to generate expression %s', type))
        end
    end

    local function genStatement(statement)
        local function genCompound(stmt)
            for i = 1, #stmt.statements do
                genStatement(stmt.statements[i])
            end
        end

        local function genWith(stmt)
            out('\n')
            local saved = scope

            for i = 1, #stmt.ids do
                local id = stmt.ids[i]
                local accessFmt = string.format('%s.%%s', accessId(id))

                local type = findId(id)

                while type.type == 'typeid' do
                    type = findId(type.id)
                end

                pushDeclarations(type.declarations, nil, accessFmt)

                while type.super do
                    type = findId(type.super)
                    pushDeclarations(type.declarations, nil, accessFmt)
                end
            end

            out('do\n')
            out:indent()
            genStatement(stmt.body)
            out:unindent()
            out('end\n\n')

            scope = saved
        end

        local function genAssignment(assignment)
            genDesignator(assignment.designator)
            out(' = ')
            genExpression(assignment.value)
            out('\n')
        end

        local function genIf(ifstmt)
            out('\n')
            out('if ')
            genExpression(ifstmt.condition)
            out(' then\n')

            out:indent()
            genStatement(ifstmt.ontrue)
            out:unindent()

            if ifstmt.onfalse then
                out('else\n')
                out:indent()
                genStatement(ifstmt.onfalse)
                out:unindent()
            end

            out('end\n\n')
        end

        local function genProcedureCall(call)
            genDesignator(call.designator)

            local designator = call.designator

            while designator.next do
                designator = designator.next
            end

            if designator.type ~= 'call' then
                out('(')

                local comma = ''

                for i = 1, #call.arguments do
                    out('%s', comma)
                    comma = ', '

                    genExpression(call.arguments[i])
                end

                out(')')
            end

            out('\n')
        end

        local function genCase(case)
            out('\n')
            out('do\n')
            out:indent()

            local id = string.format('hh2%s', tostring(case):match('.*0x(%x+).*'))
            out('local %s = ', id)
            genExpression(case.selector)
            out('\n\n')

            local stmt = 'if'

            for i = 1, #case.selectors do
                out('%s ', stmt)
                stmt = 'elseif'

                local sel = case.selectors[i]
                local orop = ''

                for j = 1, #sel.labels do
                    out(orop)
                    orop = ' or '

                    local label = sel.labels[j]

                    if label.value then
                        out('(%s == ', id)
                        genExpression(label.value)
                        out(')')
                    else
                        out('((%s >= ', id)
                        genExpression(label.min)
                        out(') and (%s <= ', id)
                        genExpression(label.max)
                        out('))')
                    end
                end

                out(' then\n')
                out:indent()
                genStatement(sel.body)
                out:unindent()
            end

            if case.otherwise then
                out('else\n')
                out:indent()
                genStatement(case.otherwise)
                out:unindent()
            end

            out('end\n')
            out:unindent()
            out('end\n')
        end

        local function genFor(forstmt)
            out('\n')
            out('for %s', accessId(forstmt.qid.id[1]))

            for i = 2, #forstmt.qid.id do
                out('.%s', forstmt.qid.id[i]:lower())
            end

            out(' = ')
            genExpression(forstmt.first)
            out(', ')
            genExpression(forstmt.last)

            if forstmt.direction == 'down' then
                out(', -1')
            end

            out(' do\n')
            out:indent()
            genStatement(forstmt.body)
            out:unindent()
            out('end\n\n')
        end

        local function genInc(inc)
            local id = {accessId(inc.qid.id[1])}

            for i = 2, #inc.qid.id do
                id[#id + 1] = inc.qid.id[i]:lower()
            end

            id = table.concat(id, '.')

            out('%s = %s + ', id, id)

            if inc.amount then
                genExpression(inc.amount)
            else
                out('1')
            end

            out('\n')
        end

        local function genDec(dec)
            local id = {accessId(dec.qid.id[1])}

            for i = 2, #dec.qid.id do
                id[#id + 1] = dec.qid.id[i]:lower()
            end

            id = table.concat(id, '.')

            out('%s = %s - ', id, id)

            if dec.amount then
                genExpression(dec.amount)
            else
                out('1')
            end

            out('\n')
        end

        local function genWhile(node)
            out('\n')
            out('while ')
            genExpression(node.condition)
            out(' do\n')
            out:indent()
            genStatement(node.body)
            out:unindent()
            out('end\n\n')
        end

        local function genAsm(node)
            out('do\n')
            out:indent()
            out('%s\n', node.code:sub(4, -5))
            out:unindent()
            out('end\n')
        end

        local function genInherited(node)
            assert(node.designator.type == 'variable')

            out('hh2rt.callInherited(%q, self', node.designator.qid.id[1]:lower())

            if node.designator.next then
                dump(node.designator.next)
                (nil)()
            end

            out(')\n')
        end

        local function genDecodeTime(node)
            out('%s, %s, %s, %s = hh2rt.decodeTimeUs(', node.hour, node.minute, node.second, node.msec)
            genExpression(node.now)
            out(')')
        end

        local function genRepeat(node)
            out('\n')
            out('repeat\n')
            out:indent()
            genStatement(node.body)
            out:unindent()
            out('until ')
            genExpression(node.condition)
            out('\n\n')
        end

        local type = statement.type

        if type == 'compoundstmt' then
            genCompound(statement)
        elseif type == 'with' then
            genWith(statement)
        elseif type == 'assignment' then
            genAssignment(statement)
        elseif type == 'if' then
            genIf(statement)
        elseif type == 'proccall' then
            genProcedureCall(statement)
        elseif type == 'case' then
            genCase(statement)
        elseif type == 'for' then
            genFor(statement)
        elseif type == 'inc' then
            genInc(statement)
        elseif type == 'dec' then
            genDec(statement)
        elseif type == 'while' then
            genWhile(statement)
        elseif type == 'asm' then
            genAsm(statement)
        elseif type == 'inherited' then
            genInherited(statement)
        elseif type == 'decodetime' then
            genDecodeTime(statement)
        elseif type == 'repeat' then
            genRepeat(statement)
        elseif type == 'emptystmt' then
            -- nothing
        else
            dump(statement)
            error(string.format('do not know how to generate statement %s', statement.type))
        end
    end

    local function genBlock(block)
        local saved = scope
        local ids = push('local %s', '%s')

        iterateDeclarations(block.declarations, function(what, id, type)
            if what == 'variable' then
                ids[id:lower()] = type
                out('%s = ', declareId(id))
                genDefaultValue(type)
                out('\n')
            elseif what == 'constant' then
                ids[id:lower()] = type
                out('%s = ', declareId(id))

                if type.subtype.type == 'arraytype' then
                    genArray(type.subtype, type.value)
                else
                    genConstValue(type.value)
                end

                out('\n')
            else
                dump(type)
                error(string.format('do not know how to generate declarition %s', what))
            end
        end)

        if block.declarations then
            out('\n')
        end

        genStatement(block.statement)
        scope = saved
    end

    local function genPascalSignature(parameters, returnType)
        if parameters then
            out('(')
            local comma1 = ''

            for i = 1, #parameters do
                local params = parameters[i]
                local subtype = params.subtype
                local comma2 = ''

                out('%s', comma1)
                comma1 = '; '

                for j = 1, #params.ids do
                    out('%s%s', comma2, params.ids[j])
                    comma2 = ', '
                end

                if subtype.type == 'typeid' then
                    out(': %s', subtype.id)
                elseif subtype.type == 'ordident' then
                    out(': %s', subtype.subtype)
                elseif subtype.type == 'stringtype' then
                    out(': String')
                else
                    dump(subtype)
                    error(string.format('do not know how to generate type %s', subtype.type))
                end
            end

            out(')')
        end

        if returnType then
            out(': ')

            if returnType.type == 'typeid' then
                out(': %s', returnType.id)
            elseif returnType.type == 'ordident' then
                out(': %s', returnType.subtype)
            else
                dump(returnType)
                error(string.format('do not know how to generate type %s', returnType.type))
            end
        end
    end

    local function genProcedureDeclaration(procedure, ismethod)
        local heading = procedure.heading

        if heading.type == 'consthead' then
            out('hh2rt.newConstructor(%s, function(', accessId(heading.qid.id[1]))
        else
            out('function(')
        end

        local saved = scope
        local ids = push(nil, '%s')

        if ismethod then
            out('self')
            ids.self = 'self'
        end

        local params = procedure.heading.parameters

        if params then
            local comma = ismethod and ', ' or ''

            for i = 1, #params do
                local param = params[i]

                for j = 1, #param.ids do
                    local id = param.ids[j]:lower()
                    ids[id] = param.subtype

                    out('%s%s', comma, id)
                    comma = ', '
                end
            end
        end

        out(')\n')
        out:indent()

        local resultId = string.format('hh2%s', tostring(procedure):match('.*0x(%x+).*'))

        if heading.type == 'funchead' then
            local resultIds = push(nil, resultId)
            resultIds[heading.qid.id[#heading.qid.id]:lower()] = true
            out('local %s = nil\n', resultId)
        end

        genBlock(procedure.block)

        if heading.type == 'funchead' then
            out('return %s\n', resultId)
        end

        out:unindent()
        out('end')

        if heading.type == 'consthead' then
            out(')')
        end

        out('\n')
        scope = saved
    end

    local function genRecord(record)
        out('hh2rt.newRecord()')
    end


    genArray = function(array, value)
        local subtype = array.subtype

        out('hh2rt.newArray({')
        local comma = ''

        for i = 1, #array.limits do
            local limit = array.limits[i]
            out('%s{', comma)
            comma = ', '

            genExpression(limit.min)
            out(', ')
            genExpression(limit.max)
            out('}')
        end

        out('}, ')

        if subtype.type == 'typeid' then
            out('nil --[[%s]]', subtype.id)
        elseif subtype.type == 'ordident' or subtype.type == 'realtype' then
            out('%s --[[%s]]', defaultValues[subtype.subtype], subtype.subtype)
        elseif subtype.type == 'rectype' then
            genRecord(subtype)
        elseif subtype.type == 'stringtype' then
            out('"" --[[%s]]', subtype.type)
        else
            dump(array)
            dump(subtype)
            error(string.format('do not know how to generate variable %s', subtype.type))
        end

        if value then
            local function genValue(v)
                if type(v) ~= 'userdata' then
                    out('%s', tostring(v))
                elseif #v ~= 0 then
                    out('{')
                    genValue(v[1])

                    for i = 2, #v do
                        out(', ')
                        genValue(v[i])
                    end

                    out('}')
                elseif v.type == 'arrayconst' then
                    out('\n')
                    out:indent()
                    genValue(v.value)
                    out:unindent()
                else
                    genLiteral(v)
                end
            end

            out(', ')
            genValue(value.value)
            out(')\n\n')
        else
            out(', nil)')
        end
    end

    genDeclarations = function(declarations, interface)
        local function genClass(class, id)
            if class.super then
                out('hh2rt.newClass(%q, %s, function(self)\n', id, accessId(class.super))
            else
                out('hh2rt.newClass(%q, nil, function(self)\n', id)
            end

            out:indent()

            for i = 1, #class.declarations do
                local decl = class.declarations[i]

                if decl.type == 'consthead' or decl.type == 'desthead' or decl.type == 'prochead' or decl.type == 'funchead' then
                    -- nothing
                elseif decl.type == 'field' then
                    local subtype = decl.subtype

                    for i = 1, #decl.ids do
                        out('self.%s = ', decl.ids[i]:lower())

                        if subtype.type == 'typeid' then
                            local type = findId(subtype.id)

                            if type.type == 'enumerated' then
                                out('%s', accessId(type.elements[1].id))
                            elseif type.type == 'class' then
                                out('%s.create()', accessId(subtype.id))
                            elseif type.type == 'proctype' then
                                out('function() end')
                            elseif type.type == 'ordident' then
                                out('%s', defaultValues[type.subtype])
                            elseif type.type == 'subrange' then
                                out('0')
                            elseif type.type == 'set' then
                                out('hh2rt.instantiateSet(%s)', accessId(subtype.id))
                            else
                                dump(decl)
                                dump(subtype)
                                dump(type)
                                error(string.format('do not know how to initialize type %s', type.type))
                            end
                        elseif subtype.type == 'ordident' then
                            out('%s', defaultValues[subtype.subtype])
                        elseif subtype.type == 'stringtype' then
                            out('""')
                        else
                            dump(decl)
                            dump(subtype)
                            error(string.format('do not know how to initialize field %s', subtype.type))
                        end

                        out('\n')
                    end
                else
                    error(string.format('do not know how to initialize declaration %s', decl.type))
                end
            end

            out:unindent()
            out('end)\n\n')
        end

        local function genEnumElements(enum)
            local last

            for i = 1, #enum.elements do
                local element = enum.elements[i]

                if element.value then
                    out('%s = ', declareId(element.id))
                    genExpression(element.value)
                    out('\n')
                else
                    out('%s = %s\n', declareId(element.id), last and (accessId(last.id) .. ' + 1') or '0')
                end

                last = element
            end
        end

        local function genEnum(enum)
            out('hh2rt.newEnum({')
            local comma = ''

            for i = 1, #enum.elements do
                out('%s%s', comma, accessId(enum.elements[i].id))
                comma = ', '
            end

            out('})')
        end

        local function genSet(set)
            out('hh2rt.newSet(')

            if set.subtype then
                genEnum(set.subtype)
            else
                out('%s', accessId(set.qid.id[1]))

                for i = 2, #set.qid.id do
                    out('.%s', set.qid.id[i]:lower())
                end
            end

            out(')')
        end

        for i = 1, #declarations do
            local decl = declarations[i]

            if decl.type == 'types' then
                for i = 1, #decl.types do
                    local type = decl.types[i]
                    local subtype = type.subtype
                    local id = type.id

                    if interface then
                        if subtype.type == 'class' then
                            out('%s = ', declareId(id))
                            genClass(subtype, id)
                            out('\n')
                        elseif subtype.type == 'ordident' then
                            out('%s = %s\n', declareId(id), tostring(defaultValues[subtype.subtype]))
                        elseif subtype.type == 'set' then
                            if subtype.subtype then
                                genEnumElements(subtype.subtype)
                            end

                            out('%s = ', declareId(id))
                            genSet(subtype)
                            out('\n')
                        elseif subtype.type == 'enumerated' then
                            genEnumElements(subtype)
                            out('%s = ', declareId(id))
                            genEnum(subtype)
                            out('\n')
                        elseif subtype.type == 'proctype' then
                            out('%s = nil -- Procedure', declareId(id))
                            genPascalSignature(subtype.subtype.parameters, nil)
                            out('\n')
                        elseif subtype.type == 'subrange' then
                            out('%s = 0 -- ', declareId(id))
                            genExpression(subtype.min)
                            out('..')
                            genExpression(subtype.max)
                            out('\n')
                        elseif subtype.type == 'typeid' then
                            out('%s = %s\n', declareId(id), accessId(subtype.id))
                        else
                            dump(type)
                            dump(subtype)
                            error(string.format('do not know how to generate type %s', subtype.type))
                        end
                    end
                end
            elseif decl.type == 'constants' then
                for i = 1, #decl.constants do
                    local const = decl.constants[i]
                    local subtype = const.subtype
                    local id = const.id
                    
                    if interface then
                        if subtype then
                            if subtype.type == 'arraytype' then
                                out('%s = ', declareId(id))
                                genArray(subtype, const.value)
                                out('\n')
                            else
                                dump(subtype)
                                error(string.format('do not know how to generate constant %s', subtype.type))
                            end
                        else
                            out('%s = ', declareId(id))
                            genExpression(const.value)
                            out('\n')
                        end
                    end
                end
            elseif decl.type == 'variables' then
                for i = 1, #decl.variables do
                    local variable = decl.variables[i]
                    local subtype = variable.subtype

                    for j = 1, #variable.ids do
                        local id = variable.ids[j]

                        if interface then
                            if subtype.type == 'typeid' then
                                out('%s = nil -- %s\n', declareId(id), subtype.id)
                            elseif subtype.type == 'arraytype' then
                                out('%s = ', declareId(id))
                                genArray(subtype)
                                out('\n')
                            elseif subtype.type == 'ordident' then
                                out('%s = %s\n', declareId(id), defaultValues[subtype.subtype])
                            elseif subtype.type == 'realtype' then
                                out('%s = %s\n', declareId(id), defaultValues[subtype.subtype])
                            elseif subtype.type == 'stringtype' then
                                out('%s = ""\n', declareId(id))
                            else
                                dump(variable)
                                dump(subtype)
                                error(string.format('do not know how to generate variable %s', subtype.type))
                            end
                        end
                    end
                end
            elseif decl.type == 'procdecl' then
                if not interface then
                    out('\n')
                    out('%s', declareId(decl.heading.qid.id[1]))

                    for i = 2, #decl.heading.qid.id do
                        out('.%s', decl.heading.qid.id[i]:lower())
                    end

                    out(' = ')

                    local type = findId(decl.heading.qid.id[1])
                    local saved = scope

                    if type.type == 'class' then
                        pushDeclarations(type.declarations, nil, 'self.%s')
                        local count = 1

                        while type.super do
                            type = findId(type.super)
                            pushDeclarations(type.declarations, nil, 'self.%s')
                            count = count + 1
                        end
                    end

                    genProcedureDeclaration(decl, type.type == 'class')
                    scope = saved
                end
            elseif decl.type == 'prochead' or decl.type == 'funchead' or decl.type == 'consthead' or decl.type == 'desthead' then
                --[[local id = table.concat(decl.qid.id, '.')
                out('%s = nil -- %s', id:lower(), id)
                genPascalSignature(decl.parameters, decl.type == 'funchead' and decl.returnType)
                out('\n')]]
            elseif decl.type == 'field' then
                if interface then
                    local subtype = decl.subtype

                    for i = 1, #decl.ids do
                        if subtype.type == 'typeid' then
                            out('%s = nil, -- %s\n', decl.ids[i], subtype.id)
                        elseif subtype.type == 'ordident' then
                            out('%s = %s, -- %s\n', decl.ids[i], defaultValues[subtype.subtype], subtype.subtype)
                        elseif subtype.type == 'stringtype' then
                            out('%s = "", -- %s\n', decl.ids[i], subtype.type)
                        else
                            dump(subtype)
                            error(string.format('do not know how to generate field %s', subtype.type))
                        end
                    end
                end
            else
                dump(decl)
                error(string.format('do not know how to generate declaration %s', decl.type))
            end
        end
    end

    local function genUses(uses)
        if uses then
            out('-- Require other units\n')

            for i = 1, #uses.units do
                local unit = uses.units[i]
                local path = findUnit(unit, searchPaths)

                if not path then
                    fatal(uses.line, 'Cannot find the path to unit "%s"', unit)
                end

                unit = unit:lower()
                out('local %s = require "%s"\n', unit, unit)

                local ast, err = parse(path, macros)

                if not ast then
                    fatal(uses.line, err)
                end

                pushDeclarations(ast.interface.declarations, nil, unit .. '.%s')
                push(nil, '%s')[unit:lower()] = ast
            end

            out('\n')
        end
    end

    local function genUnit(unit)
        out('-- Generated code for Pascal unit "%s"\n\n', unit.id)
        out('-- Our exported module\n')
        out('local M = {}\n\n')
        out('-- Load the runtime and the implied system unit\n')
        out('local hh2rt = require "hh2rt"\n')

        if unit.id:lower() ~= 'system' then
            out('local system = require "system"\n\n')
        else
            out('\n')
        end

        do
            local path = findUnit('system', searchPaths)

            if not path then
                fatal(node.line, 'Cannot find the path to unit "system"')
            end

            local ast, err = parse(path, macros)

            if not ast then
                fatal(unit.line, err)
            end

            pushDeclarations(ast.interface.declarations, nil, 'system.%s')
            push(nil, '%s')['system'] = ast
        end

        out('\n')
        out('-- Interface section\n')
        genUses(unit.interface.uses)
        pushDeclarations(unit.interface.declarations, 'M.%s', 'M.%s')
        genDeclarations(unit.interface.declarations, true)

        out('\n')
        out('-- Implementation section\n')
        genUses(unit.implementation.uses)
        pushDeclarations(unit.implementation.declarations, 'local %s', '%s')
        genDeclarations(unit.implementation.declarations, false)

        if unit.initialization.statements then
            out('\n')
            out('-- Initialization section\n')

            for i = 1, #unit.initialization.statements do
                genStatement(unit.initialization.statements[i])
            end
        end

        out('\n')
        out('-- Return the module\n')
        out('return M\n')
    end

    out('-- Generated from "%s"\n', ast.path)
    genUnit(ast)
end

if #arg == 0 then
    print(string.format('Usage: lua %s [-D<macro>...] [-I<include_dir_path>...] <input_file_path>', arg[0]))
    os.exit(1)
end

-- Pasrse command line arguments
local macros, searchPaths = {}, {}
local input_path

for i = 1, #arg do
    if arg[i]:sub(1, 2) == '-D' then
        macros[arg[i]:sub(3, -1):lower()] = true
    elseif arg[i]:sub(1, 2) == '-I' then
        searchPaths[#searchPaths + 1] = arg[i]:sub(3, -1)
    else
        input_path = arg[i]
    end
end

-- Add the path to the input file to the search paths
do
    local dir, _, _ = ddlt.split(input_path)

    if dir then
        searchPaths[#searchPaths + 1] = dir
    end
end

-- Create sets with the contents of the search paths
for i = 1, #searchPaths do
    local search_path = searchPaths[i]
    local entries, err = ddlt.scandir(search_path)

    if not entries then
        print(string.format('%s:0: Error listing files in "%s": %s', input_path, search_path, err))
        os.exit(1)
    end

    local set = {}

    for j = 1, #entries do
        local entry = entries[j]
        local info = ddlt.stat(entry)

        if info.file then
            set[entry:lower()] = entry
        end
    end

    searchPaths[i] = set
end

-- Parse the main file
local ast, err = parse(input_path, macros)

if not ast then
    print(err)
    os.exit(1)
end

-- Generate code
local out

do
    local props = {
        level = 0,
        code = {},

        indent = function(self)
            self.level = self.level + 1
        end,

        unindent = function(self)
            self.level = self.level - 1
        end,

        spaces = function(self)
            return string.rep('    ', self.level)
        end,

        result = function(self)
            local str = table.concat(self.code, '')

            while true do
                local str2 = str:gsub('\n%s-\n%s-\n+', '\n\n')

                if str2 == str then
                    return str
                end

                str = str2
            end
        end
    }

    local mt = {
        __call = function(self, ...)
            local str = string.format(...)

            if #self.code ~= 0 and self.code[#self.code]:sub(-1, -1) == '\n' then
                self.code[#self.code + 1] = self:spaces()
            end

            local first = true

            for line in str:gmatch('(.-)\n') do
                if first then
                    first = false
                else
                    self.code[#self.code + 1] = self:spaces()
                end

                self.code[#self.code + 1] = line
                self.code[#self.code + 1] = '\n'
            end

            local last

            for i = #str, 1, -1 do
                if str:byte(i) == 10 then
                    last = i
                    break
                end
            end

            if last == nil then
                self.code[#self.code + 1] = str
            elseif last ~= #str then
                self.code[#self.code + 1] = last
            end
        end,
    }

    out = debug.setmetatable(props, mt)
end

--[[local ok, err = pcall(generate, ast, out)

if not ok then
    print(err)
    os.exit(1)
end]]

local ok, err = xpcall(generate, debug.traceback, ast, searchPaths, macros, out)

print(out:result())

if not ok then
    io.stderr:write(err, '\n')
end
