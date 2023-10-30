TurtleMove = {};

TurtleMove.memory = {};
TurtleMove.position = nil;
TurtleMove.facing = nil;
TurtleMove.debug = true;

--- Coordinate methods

Coords2 = {
    mt = {}
};

Coords3 = {
    mt = {}
};

function coords2(x, z)
    local coords = {x = x, z = z};
    setmetatable(coords, Coords2.mt);
    return coords;
end

function coords3(x, y, z)
    local coords = {x = x, y = y, z = z};
    setmetatable(coords, Coords3.mt);
    return coords;
end

function Coords2.mt.__tostring(c2)
    return "(" .. c2.x .. ", " .. c2.z .. ")";
end

function Coords2.mt.__add(a, b)
    return coords2(a.x + b.x, a.z + b.z);
end

function Coords2.mt.__sub(a, b)
    return coords2(a.x - b.x, a.z - b.z);
end

function Coords2.mt.__eq(a, b)
    return a.x == b.x and a.z == b.z;
end

function Coords2.mt.__concat(a, b)
    return tostring(a) .. tostring(b);
end

function Coords3.mt.__tostring(c3)
    return "(" .. c3.x .. ", " .. c3.y .. ", " .. c3.z .. ")";
end

function Coords3.mt.__add(a, b)
    x = a.x + b.x;
    y = b.y and a.y + b.y or a.y;
    z = a.z + b.z;
    return coords3(x, y, z);
end

function Coords3.mt.__sub(a, b)
    x = a.x - b.x;
    y = b.y and a.y - b.y or a.y;
    z = a.z - b.z;
    return coords3(x, y, z);
end

function Coords3.mt.__eq(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z;
end

function Coords3.mt.__concat(a, b)
    return tostring(a) .. tostring(b);
end

--- Movement methods

-- the coordinate system is relative to the initial position
-- +x = forward
-- +y = up
-- +z = right

local function debugMove()
    if TurtleMove.debug then
        print("Moving to " .. TurtleMove.position);
    end
end

local function debugRotate(direction)
    if TurtleMove.debug then
        print("Rotating " .. direction .. " and facing " .. TurtleMove.facing);
    end
end

function TurtleMove.initPosition()
    TurtleMove.position = coords3(0, 0, 0);
    TurtleMove.facing = coords2(1, 0);
end

function TurtleMove.forward(n)
    n = n or 1;
    for i = 1, n do
        TurtleMove.position.x = TurtleMove.position.x + TurtleMove.facing.x;
        TurtleMove.position.z = TurtleMove.position.z + TurtleMove.facing.z;
        if not turtle.forward() then
            return false, i - 1;
        end
        debugMove();
    end
    return true, n;
end

function TurtleMove.back(n)
    n = n or 1;
    for i = 1, n do
        TurtleMove.position.x = TurtleMove.position.x - TurtleMove.facing.x;
        TurtleMove.position.z = TurtleMove.position.z - TurtleMove.facing.z;
        if not turtle.back() then
            return false, i - 1;
        end
        debugMove();
    end
    return true, n;
end

function TurtleMove.up(n)
    n = n or 1;
    for i = 1, n do
        TurtleMove.position.y = TurtleMove.position.y + 1;
        if not turtle.up() then
            return false, i - 1;
        end
        debugMove();
    end
    return true, n;
end

function TurtleMove.down(n)
    n = n or 1;
    for i = 1, n do
        TurtleMove.position.y = TurtleMove.position.y - 1;
        if not turtle.down() then
            return false, i - 1;
        end
        debugMove();
    end
    return true, n;
end

-- lets hope this works
local rightTurnTable = {
    [tostring(coords2(1, 0))] = coords2(0, 1),
    [tostring(coords2(0, 1))] = coords2(-1, 0),
    [tostring(coords2(-1, 0))] = coords2(0, -1),
    [tostring(coords2(0, -1))] = coords2(1, 0)
};

local leftTurnTable = {
    [tostring(coords2(1, 0))] = coords2(0, -1),
    [tostring(coords2(0, -1))] = coords2(-1, 0),
    [tostring(coords2(-1, 0))] = coords2(0, 1),
    [tostring(coords2(0, 1))] = coords2(1, 0)
};

function TurtleMove.turnRight()
    TurtleMove.facing = rightTurnTable[tostring(TurtleMove.facing)];
    turtle.turnRight();
    debugRotate("right");
end

function TurtleMove.turnLeft()
    TurtleMove.facing = leftTurnTable[tostring(TurtleMove.facing)];
    turtle.turnLeft();
    debugRotate("left");
end

--- Memory methods
function TurtleMove.remember(tag, block, where)
    local position = TurtleMove.position + where;
    TurtleMove.memory[tag] = {
        name = block.name,
        position = position
    };
    if TurtleMove.debug then
        print("Remembering block [" .. block.name .. "] by tag [" .. tag .. "] at position " .. position);
    end
end

function TurtleMove.rememberForward(tag, block)
    return TurtleMove.remember(tag, block, coords3(TurtleMove.facing.x, 0, TurtleMove.facing.z))
end

function TurtleMove.rememberUp(tag, block)
    return TurtleMove.remember(tag, block, coords3(0, 1, 0));
end

function TurtleMove.rememberDown(tag, block)
    return TurtleMove.remember(tag, block, coords3(0, -1, 0));
end

-- Detection methods
function TurtleMove.inspect()
    local pos = TurtleMove.position + TurtleMove.facing;
    return turtle.inspect(), pos;
end

function TurtleMove.inspectUp()
    local pos = TurtleMove.position + coords3(0, 1, 0);
    return turtle.inspectUp(), pos;
end

function TurtleMove.inspectDown()
    local pos = TurtleMove.position + coords3(0, -1, 0);
    return turtle.inspectDown(), pos;
end


return TurtleMove;