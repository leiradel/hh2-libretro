return {
    newClass = function(...)
        return {__superClasses = {...}}
    end,

    newConstructor = function(class, id, constructor)
        class[id] = function(...)
            return constructor({}, ...)
        end
    end,

    newEnum = function(elements)
        return elements
    end,

    newSet = function(enum)
        return {__enum = enum}
    end,

    newArray = function(dimensions, default, value)
        local function init(array, dimensions, default, value, i)
            local min = dimensions[i][1]
            local max = dimensions[i][2]

            if i < #dimensions then
                if value then
                    local k = 1

                    for j = min, max do
                        array[j] = {}
                        init(array[j], dimensions, default, value[k], i + 1)
                    end
                else
                    for j = min, max do
                        array[j] = {}
                        init(array[j], dimensions, default, nil, i + 1)
                    end
                end
            else
                if value then
                    local k = 1

                    for j = min, max do
                        array[j] = value[k]
                        k = k + 1
                    end
                else
                    for j = min, max do
                        array[j] = default
                    end
                end
            end
        end

        local array = {}
        init(array, dimensions, default, value, 1)
        return array
    end,

    newRecord = function()
        return {}
    end
}
