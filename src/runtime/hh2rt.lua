local meta = {}

return {
    newClass = function(...)
        local class = {}
        meta[class] = {...} -- super classes
        return class
    end,

    newConstructor = function(class, constructor)
        local function setMethods(class, instance)
            for k, v in pairs(class) do
                if not instance[k] then
                    print(k, v)
                    instance[k] = function(...)
                        return v(instance, ...)
                    end
                end
            end

            local superClasses = meta[class]

            for i = #superClasses, 1, -1 do
                setMethods(superClasses[i], instance)
            end
        end

        return function(...)
            local instance = {}
            setMethods(class, instance)
            constructor(instance, ...)
            return instance
        end
    end,

    newEnum = function(elements)
        return elements
    end,

    newSet = function(enum)
        local set = {}
        meta[set] = enum
        return set
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
