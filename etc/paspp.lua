return function(path, tokens)
    local source = {
        'return function(macros)',
        '    local source = {}'
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
                out('    if macros.%s then', id)
            elseif dir == 'ifndef' then
                out('    if not macros.%s then', id)
            elseif dir == 'else' then
                out('    else')
            elseif dir == 'endif' then
                out('    end')
            elseif dir == 'r' then
                -- Discard
            else
                return nil, string.format('%s:%u: unhandled directive "%s"', path, la.line, dir)
            end
        elseif la.token ~= '<eof>' then
            out('    source[%d] = (source[%d] or "") .. %q', la.line, la.line, la.lexeme .. ' ')
        end
    end

    source[#source + 1] = '    for i = 1, ' .. tokens[#tokens].line .. ' do'
    source[#source + 1] = '        source[i] = source[i] or ""'
    source[#source + 1] = '    end'
    source[#source + 1] = '    return table.concat(source, "\\n")'
    source[#source + 1] = 'end'

    return table.concat(source, '\n')
end
