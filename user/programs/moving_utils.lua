DIRECTION_TABLE = {
    n = vector.new(0, 0, -1),
    w = vector.new(-1, 0, 0),
    s = vector.new(0, 0, 1),
    e = vector.new(1, 0, 0),
    up = vector.new(0, 1, 0),
    down = vector.new(0, -1, 0)
}

LEFT_TURNTABLE = {
    w = "s",
    e = "n",
    n = "w",
    s = "e"
}

RIGHT_TURNTABLE = {
    w = "n",
    e = "s",
    n = "e",
    s = "w"
}

ANGLE_TO_ROTATION = {
    -- NOTE: we must not use direct pointers to turtle methods here because they are overridden in `initTurtle`
    [90] = function () turtle.turnRight() end,
    [-270] = function () turtle.turnRight() end,
    [180] = function ()
        turtle.turnRight();
        turtle.turnRight();
    end,
    [-180] = function ()
        turtle.turnLeft();
        turtle.turnLeft()
    end,
    [-90] = function () turtle.turnLeft() end,
    [270] = function () turtle.turnLeft() end,
    [360] = function () end,
    [0] = function () end
}

AXIS_TO_COMPASS_DIRECTION = {
    x = {
        [-1] = "w",
        [1] = "e"
    },
    y = {
        [-1] = "down",
        [1] = "up",
    },
    z = {
        [-1] = "n",
        [1] = "s",
    }
}

REVERSE_MOVEMENTS = {
    n = "s",
    s = "n",
    e = "w",
    w = "e",
    up = "down",
    down = "up"
}

ZERO_VECTOR = vector.new(0, 0, 0);

function taxicab(vec1, vec2)
    local diff = vec1 - vec2;
    return math.abs(diff.x) + math.abs(diff.y) + math.abs(diff.z);
end

function getCompassDirection(vec)
    if vec.x == -1 then
        return "w";
    elseif vec.x == 1 then
        return "e";
    else
        if vec.z == -1 then
            return "n";
        else
            return "s";
        end
    end
end

function rotateVectorLeft(vec)
    if vec.x == -1 then
        -- w -> s
        return DIRECTION_TABLE.s;
    elseif vec.x == 1 then
        -- e -> n
        return DIRECTION_TABLE.n;
    else
        if vec.z == -1 then
            -- n -> w
            return DIRECTION_TABLE.w;
        else
            -- s -> e
            return DIRECTION_TABLE.e;
        end
    end
end

function rotateVectorRight(vec)
    if vec.x == -1 then
        -- w -> n
        return DIRECTION_TABLE.n;
    elseif vec.x == 1 then
        -- e -> s
        return DIRECTION_TABLE.s;
    else
        if vec.z == -1 then
            -- n -> e
            return DIRECTION_TABLE.e;
        else
            -- s -> w
            return DIRECTION_TABLE.w;
        end
    end
end

local function calculateAngle(dir1, dir2)
    local toTheLeft = LEFT_TURNTABLE[dir1];
    if toTheLeft == dir2 then
        return -90;
    end
    local toTheRight = RIGHT_TURNTABLE[dir1];
    if toTheRight == dir2 then
        return 90;
    end
    local behindIt = RIGHT_TURNTABLE[toTheRight];
    if behindIt == dir2 then
        return 180;
    end
    return error("What is '" .. dir2 .. "'? What is it doing here?");
end

local function turnTowardsCompassDirection(dir)
    if dir == turtle.compassDirection then
        return;
    end
    local angle = calculateAngle(turtle.compassDirection, dir);
    ANGLE_TO_ROTATION[angle]();
end

function lookTowards(direction)
    turnTowardsCompassDirection(direction);
end

function goTo(parameters)

    local function getDetectMethod(direction)
        if direction == "up" then
            return function () return turtle.detectUp() end;
        elseif direction == "down" then
            return function () return turtle.detectDown() end;
        else
            return function () return turtle.detect() end;
        end
    end

    local function getMoveMethod(direction)
        if direction == "up" then
            return function () return turtle.up() end;
        elseif direction == "down" then
            return function () return turtle.down() end;
        else
            return function () return turtle.forward() end;
        end
    end

    local function rotateIfNecessary(moveDirection)
        if moveDirection ~= "down" and moveDirection ~= "up" then
            turnTowardsCompassDirection(moveDirection);
        end
    end

    -- 'target' and 'tag' are mutually exclusive parameters
    local target = parameters.target or turtle.taggedPositions[parameters.tag];
    assert(target, "no target");

    local faceDirection = parameters.faceDirection;
    local origin = turtle.pos;

    local diffToTarget = doubleNormalize(target - origin);
    if diffToTarget == ZERO_VECTOR then return {state = "done"} end;
    local diffToOrigin = ZERO_VECTOR;
    -- TODO: add callbacks for every location in 'path' type parameters so the turtle can perform an action before moving on, or think of a different way to stop and then continue on its way
    -- TODO: 'pathTags' parameter for navigating through a path of tagged locations
    -- TODO: 'tag' parameter for navigating towards a location by its tag
    -- TODO: add filesystem storage for tagged locations which are loaded into memory at startup
    -- TODO: 'path' parameter with a list of locations to visit in order
    -- TODO: consider removing virtual blocks or improving them because theyre barely used now
    -- TODO: return paths that the turtle found from point A to point B, stored as a sequence of movements, same as in mine_vein
    -- TODO: save paths in memory, load them when the turtle wants to trace the path again, when the path is interrupted, we must cut it
    --       at that point and let continue with the usual algorithm while updating the path
    -- TODO: store special locations in the turtles filesystem, we could then for example do:
    --         turtle.remember(vector.new(300, 60, -50), "iron_furnace")
    --         turtle.goTo("iron_furnace")
    --       and the turtle would either trace a new path to iron_furnace or use an existing one, if it intersects an existing path accidentally
    --       then it should continue along that path, in this case we only want to take paths that have "iron_furnace" as their target tag name

    -- virtual blocks are positions which we backtracked out of and know are dead ends
    local virtualBlocks = {};
    local stepNumber = 0;
    local visitedPositions = {
        [vec2str(turtle.pos)] = stepNumber
    };

    local function shouldSkipMove(direction)
        local potentialPosition = turtle.pos + DIRECTION_TABLE[direction];
        return virtualBlocks[vec2str(potentialPosition)];
    end

    local function generateMoves()
        local backtrackingMoves = {};
        local regularMoves = {};

        for k, v in pairs(DIRECTION_TABLE) do
            local step = visitedPositions[vec2str(turtle.pos + v)];
            local positionInfo = {
                direction = k,
                -- increased by looking towards target, decreased by looking towards origin
                dot = diffToTarget:dot(v) - diffToOrigin:dot(v),
            }
            if step then
                positionInfo.stepNumber = step;
                table.insert(backtrackingMoves, positionInfo);
            else
                table.insert(regularMoves, positionInfo);
            end
        end
        -- regular moves sorted by most direct vector towards target and most direct vector away from origin
        table.sort(regularMoves, function (a, b) return a.dot > b.dot end);
        -- backtracking moves sorted by increasing step number, moves with smaller step numbers were made first
        table.sort(backtrackingMoves, function (a, b) return a.stepNumber < b.stepNumber end);
        return table.addAll(regularMoves, backtrackingMoves);
    end

    repeat
        local positionBeforeMoving = vec2str(turtle.pos);
        local moves = generateMoves();

        local moved = false;
        for i, move in ipairs(moves) do
            local direction = move.direction;

            if not shouldSkipMove(direction) then
                rotateIfNecessary(direction);

                if not getDetectMethod(direction)() then
                    getMoveMethod(direction)();
                    stepNumber = stepNumber + 1;
                    visitedPositions[vec2str(turtle.pos)] = stepNumber;
                    moved = true;
                    break;
                end
            end

            if i == 6 then
                -- this was the last possible move
                if moved then
                    -- if it was taken that means we escaped from a dead end
                    virtualBlocks[positionBeforeMoving] = true;
                else
                    return {
                        state = "stuck",
                        reason = "no path to target"
                    };
                end
            end
        end

        -- doubleNormalize here makes it so the closer we are to the target, the more the vector towards it factors in while choosing moves
        diffToTarget = doubleNormalize(target - turtle.pos);
        diffToOrigin = doubleNormalize(origin - turtle.pos);
    until target == turtle.pos;

    if faceDirection then
        lookTowards(faceDirection);
    end

    return {
        state = "done"
    };
end