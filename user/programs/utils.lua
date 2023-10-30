function noop() end;

function identity(object) return object  end;

function fitsPattern(pattern) return function (s) return string.find(s, pattern) end end;

function truePredicate() return function (_) return true end end;

function table.filter(t, predicate)
    local j, n = 1, #t;

    for i = 1, n do
        if predicate(t[i], i) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end
    return t;
end

function table.split(t, predicate)
    local left = {};
    local right = {};
    local n = #t;

    for i = 1, n do
        local value = t[i];
        if predicate(value, i) then
            table.insert(left, value);
        else
            table.insert(right, value);
        end
    end
    return left, right;
end

function table.addAll(t1, t2)
    for _, v in ipairs(t2) do
        table.insert(t1, v);
    end
    return t1;
end

function table.tostring(t)
    local s = "{";
    for k, v in pairs(t) do
        local vString = type(v) == "table" and table.tostring(v) or tostring(v);
        s = s .. tostring(k) .. "=" .. vString .. ", "
    end
    s = s .. "}";
    return s;
end

function table.transform(t, filter, mapper)
    filter = filter or function (_, _) return true end;
    mapper = mapper or function (_, v) return v end;
    local newT = {};
    for k, v in pairs(t) do
        if filter(k, v) then
            newT[k] = mapper(k, v);
        end
    end
    return newT;
end

function table.map(t, mapper)
    mapper = mapper or function (_, v) return v end;
    for k, v in pairs(t) do
        t[k] = mapper(k, v);
    end
    return t;
end

function toboolean(str)
    return str == "true";
end

function vec2str(vec)
    return vec.x .. "," .. vec.y .. "," .. vec.z;
end

function str2vec(str)
    local _, _, x, y, z = string.find(str, "(.+),(.+),(.+)");
    return vector.new(x, y, z);
end

function vector.extractDimension(vec, direction)
    return vector.new(
            vec.x * math.abs(direction.x),
            vec.y * math.abs(direction.y),
            vec.z * math.abs(direction.z)
    );
end

function getAxis(v)
    local x, y, z = math.abs(v.x), math.abs(v.y), math.abs(v.z);
    if x > y then
        return x > z and "x" or "z";
    end
    return y > z and "y" or "z";
end

function transformTable(t, filter, mapper)
    filter = filter or function (_, _) return true end;
    mapper = mapper or function (_, v) return v end;
    local newT = {};
    for k, v in pairs(t) do
        if filter(k, v) then
            newT[k] = mapper(k, v);
        end
    end
    return newT;
end

function safeDiv(a, b)
    if b == 0 then
        if a > 0 then return math.huge else return -math.huge end;
    else
        return a / b;
    end
end

function invertVector(vec)
    vec.x = safeDiv(1, vec.x);
    vec.y = safeDiv(1, vec.y);
    vec.z = safeDiv(1, vec.z);
    return vec;
end

function doubleNormalize(vec)
    local len = vec:length();
    if len == 0 then
        return vec;
    end
    return vec / (len * len);
end

function maybeCall(fn, ...)
    return fn and fn(unpack(arg));
end

function boundingBox(bottomLeft, topRight, params)

    --local function reallyComplexCheckingIdk()
    --    function (pos, facing)
    --        local nextMove = pos + facing;
    --        if getAxis(facing) == "x" then
    --            local withinXBounds = isWithinBounds(nextMove, "x");
    --            return maybeCall(
    --                    (pos.x == bottomLeft.x and not withinXBounds) and
    --                            (
    --                                    (pos.z == bottomLeft.z and params.atBottomLeftCorner)
    --                                            or (pos.z == topRight.z and params.atBottomRightCorner)
    --                                            or params.atBottomEdge
    --                            ) or (pos.x == topRight.x and not withinXBounds) and
    --                            (
    --                                    (pos.z == topRight.z and params.atTopRightCorner)
    --                                            or (pos.z == bottomLeft.z and params.atTopLeftCorner)
    --                                            or params.atTopEdge
    --                            )
    --            );
    --        else
    --            local withinZBounds = isWithinBounds(nextMove, "z");
    --            if pos.z == bottomLeft.z and not withinZBounds then
    --                if pos.x == bottomLeft.x then return maybeCall(params.atBottomLeftCorner);
    --                elseif pos.x == topRight.x then return maybeCall(params.atTopLeftCorner);
    --                else return maybeCall(params.atLeftEdge); end
    --            elseif pos.z == topRight.z and not withinZBounds then
    --                if pos.x == topRight.x then return maybeCall(params.atTopRightCorner);
    --                elseif pos.x == bottomLeft.x then return maybeCall(params.atBottomRightCorner);
    --                else return maybeCall(params.atRightEdge); end
    --            end
    --        end
    --    end
    --end

    -- TODO: this is too complicated, I no longer understand it
    local box = {
        -- Z = left/right
        -- X = top/bottom
        topRight = topRight,
        bottomLeft = bottomLeft,
        checkPosition = function (pos, facing)
            local withinBounds = function (pos, axis)
                return bottomLeft[axis] < pos[axis] and pos[axis] < topRight[axis];
            end

            local nextMove = pos + facing;

            if getAxis(facing) == "x" then
                if pos.x == bottomLeft.x and not withinBounds(nextMove, "x") then
                    if pos.z == bottomLeft.z then
                        return maybeCall(params.atCorner, -1, -1);
                    elseif pos.z == topRight.z then
                        return maybeCall(params.atCorner, -1, 1);
                    else
                        return maybeCall(params.atBottomEdge);
                    end
                elseif pos.x == topRight.x and not withinBounds(nextMove, "x") then
                    if pos.z == topRight.z then
                        return maybeCall(params.atCorner, 1, 1);
                    elseif pos.z == bottomLeft.z then
                        return maybeCall(params.atCorner, 1, -1);
                    else
                        return maybeCall(params.atTopEdge);
                    end
                end
            else
                if pos.z == bottomLeft.z and not withinBounds(nextMove, "z") then
                    if pos.x == bottomLeft.x then
                        return maybeCall(params.atCorner, -1, -1);
                    elseif pos.x == topRight.x then
                        return maybeCall(params.atCorner, 1, -1);
                    else
                        return maybeCall(params.atLeftEdge);
                    end
                elseif pos.z == topRight.z and not withinBounds(nextMove, "z") then
                    if pos.x == topRight.x then
                        return maybeCall(params.atCorner, 1, 1);
                    elseif pos.x == bottomLeft.x then
                        return maybeCall(params.atCorner, -1, 1);
                    else
                        return maybeCall(params.atRightEdge);
                    end
                end
            end
        end
    };
    return box;
end