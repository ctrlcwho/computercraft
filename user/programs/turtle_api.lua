DEBUG = true;

dofile("/user/programs/utils.lua");
dofile("/user/programs/file_utils.lua");
dofile("/user/programs/moving_utils.lua");
dofile("/user/programs/command_utils.lua");
dofile("/user/programs/inventory_utils.lua");
dofile("/user/programs/farming_utils.lua");

local TAG_FILE_PATH = "/user/data/tags.data";

function printDebug(msg)
    if DEBUG then
        log(msg);
    end
end

-- uses gps, this will move the turtle in at least one axis to figure out what direction it's facing, cannot find direction when the turtle is enclosed
local function findOrientation()
    local tryMoving = function ()
        if turtle.forward() then
            local pos = vector.new(gps.locate());
            -- this will always be a unit vector because we moved by one block only
            turtle.back();
            return pos - turtle.pos;
        elseif turtle.back() then
            local pos = vector.new(gps.locate());
            turtle.forward();
            return pos - turtle.pos;
        else
            return nil;
        end
    end

    local orientation = tryMoving();
    if orientation then return orientation end;

    turtle.turnRight();
    orientation = tryMoving();
    turtle.turnLeft();
    if orientation then return orientation end;
    return nil;
end

-- command that will make the turtle sleep for some time, tracks the time so that if the timeout is interrupted it can resume waiting
local function delay(parameters)
    local timeout = assert(parameters.timeout);
    local startedAt = assert(parameters.startedAt);
    local currentTime = os.epoch("utc") / 1000;

    -- calculate how much longer we need to sleep
    local timeSlept = currentTime - startedAt;
    local timeLeftToSleep = timeout - timeSlept;
    if timeLeftToSleep <= 0 then
        return {state = "done"};
    end

    os.sleep(timeLeftToSleep);
    return {state = "done"};
end

local function delayIgnoringInterrupts(parameters)
    local timeout = assert(parameters.timeout);
    os.sleep(timeout);
    return {state = "done"};
end

function initTurtle(shouldOrient, turtleCoordinates, turtleOrientation)
    if turtle.pos then
        -- do not initialize the turtle twice, bad things can happen
        return;
    end

    shouldOrient = shouldOrient == nil or true;
    local x, y, z = gps.locate();
    if not x then
        if turtleCoordinates and turtleOrientation then
            -- manually entered coordinates
            turtle.pos = turtleCoordinates;
            turtle.facing = turtleOrientation;
            turtle.compassDirection = getCompassDirection(turtle.facing);
        else
            -- relative coordinates by default
            turtle.pos = vector.new(0, 0, 0);
            -- no point in orienting if we don't know the real coordinates
            turtle.facing = DIRECTION_TABLE.n;
            turtle.compassDirection = "n";
        end
    else
        turtle.pos = vector.new(x, y, z);
        if shouldOrient then
            turtle.facing = findOrientation();
            if not turtle.facing then
                error("Cannot orient turtle, it's blocked from all four sides");
            end
            turtle.compassDirection = getCompassDirection(turtle.facing);
        end
    end

    -- add "memory" to the turtle so it can remember where it was
    turtle.visitedPositions = {[vec2str(turtle.pos)] = true};
    turtle.knownBlocks = {};

    local function overrideMoveMethod(name, directionSupplier)
        local oldMethod = turtle[name];
        turtle[name] = function ()
            local moveResult = oldMethod();
            local maybeNewPosition = turtle.pos + directionSupplier();
            if moveResult then
                -- if we moved, that means we visited a new position and there is no block there
                turtle.pos = maybeNewPosition;
                local stringPos = vec2str(turtle.pos);
                turtle.visitedPositions[stringPos] = true;
                turtle.knownBlocks[stringPos] = false;
            else
                -- if we didn't move, that means we know of a block at where we wanted to move
                turtle.knownBlocks[vec2str(maybeNewPosition)] = true;
            end
            return moveResult;
        end
    end

    local function overrideTurnMethod(name, rotateMethod)
        local oldMethod = turtle[name];
        turtle[name] = function ()
            turtle.facing = rotateMethod(turtle.facing);
            turtle.compassDirection = getCompassDirection(turtle.facing);
            return oldMethod();
        end
    end

    local function overrideDetectMethod(name, directionSupplier)
        local oldMethod = turtle[name];
        turtle[name] = function()
            local detected = oldMethod();
            local position = turtle.pos + directionSupplier();
            turtle.knownBlocks[vec2str(position)] = detected;
            return detected;
        end
    end

    local function overrideInspectMethod(name, directionSupplier)
        local oldMethod = turtle[name];
        turtle[name] = function()
            local exists, block = oldMethod();
            local position = turtle.pos + directionSupplier();
            turtle.knownBlocks[vec2str(position)] = exists;
            return exists, block;
        end
    end

    -- override the movement functions here
    overrideMoveMethod("forward", function () return turtle.facing end);
    overrideMoveMethod("back", function () return -turtle.facing end);
    overrideMoveMethod("up", function () return DIRECTION_TABLE.up end);
    overrideMoveMethod("down", function () return DIRECTION_TABLE.down end);

    overrideTurnMethod("turnRight", rotateVectorRight);
    overrideTurnMethod("turnLeft", rotateVectorLeft);

    -- override detect and inspect methods
    overrideDetectMethod("detect", function () return turtle.facing end);
    overrideDetectMethod("detectUp", function () return DIRECTION_TABLE.up end);
    overrideDetectMethod("detectDown", function () return DIRECTION_TABLE.down end);

    overrideInspectMethod("inspect", function () return turtle.facing end);
    overrideInspectMethod("inspectUp", function () return DIRECTION_TABLE.up end);
    overrideInspectMethod("inspectDown", function () return DIRECTION_TABLE.down end);

    -- store commands, these are basically actions that take a long/indefinite time, like farming or auto crafting,
    -- the last issued command is resumed on startup

    turtle.commands = {
        goTo = {
            fn = CMD.wrapCommand("goTo", goTo),
            valueTransformer = function (k, v)
                if k == "target" then return str2vec(v) end;
                if k == "faceDirection" then return v end;
                if k == "tag" then return v end;
                return deserializationError();
            end
        },
        delay = {
            fn = CMD.wrapCommand("delay", delay, function (params)
                params.startedAt = params.startedAt or os.epoch("utc");
            end),
            valueTransformer = function (k, v)
                if k == "timeout" then return tonumber(v) end;
                if k == "startedAt" then return tonumber(v) end;
                return deserializationError();
            end
        },
        delayIgnoringInterrupts = {
            fn = CMD.wrapCommand("delayIgnoringInterrupts", delayIgnoringInterrupts),
            valueTransformer = function (k, v)
                if k == "timeout" then return tonumber(v) end;
                return deserializationError();
            end
        },
        take = {
            fn = CMD.wrapCommand("take", function (params)
                assert(params.name);
                local direction = params.direction or "front";

                local inventory = peripheral.wrap(direction);
                if not inventory then
                    return {
                        itemsTaken = 0,
                        error = "Couldn't open inventory"
                    }
                end;
                return {
                    itemsTaken = INV.takeItems(inventory, fitsPattern(params.name), params.count, function (countAlreadyTransferred)
                        local newParams = {
                            name = params.name,
                            direction = direction,
                            count = params.count - countAlreadyTransferred
                        };
                        CMD.updateOwnState(newParams);
                    end)
                };
            end),
            valueTransformer = function (k, v)
                if k == "direction" then return v end;
                if k == "count" then return tonumber(v) end;
                if k == "name" then return v end;
                return deserializationError();
            end
        },
        drop = {
            fn = CMD.wrapCommand("drop", function (params)
                assert(params.name);
                local count = params.count or 1;
                local direction = params.direction or "front";

                return INV.drop(fitsPattern(name), count, direction);
            end),
            valueTransformer = function (k, v)
                if k == "direction" then return v end;
                if k == "count" then return tonumber(v) end;
                if k == "name" then return v end;
                return deserializationError();
            end
        },
        farm = {
            fn = CMD.wrapCommand("farm", FARM.crops),
            valueTransformer = function (k, v)
                if k == "width" then return tonumber(v) end;
                if k == "length" then return tonumber(v) end;
                if k == "tallCrops" then return toboolean(v) end;
                if k == "facing" then return str2vec(v) end;
                if k == "state" then return v end;
                if k == "startingPoint" then return str2vec(v) end;
                return deserializationError();
            end
        }
    };

    -- create a file for storing issued commands and a file for storing command results
    local function makefile(path)
        if not fs.exists(path) then
            local file = fs.open(path, "w");
            file.close();
        end
    end
    makefile(COMMAND_FILE_PATH);
    makefile(COMMAND_RESULT_FILE_PATH);
    makefile(TAG_FILE_PATH);

    -- functions for tagging locations and loading tags at startup
    turtle.tagLocation = function (tag, direction, position)
        position = position or turtle.pos;
        direction = direction or getCompassDirection(turtle.facing);

        local entry = {
            pos = position,
            facing = direction
        };
        turtle.taggedPositions[tag] = entry;

        local serializedEntry = vec2str(position) .. "|" .. direction;

        local tags = deserializePath(TAG_FILE_PATH);
        tags[tag] = serializedEntry
        serializePath(TAG_FILE_PATH, tags);
    end

    turtle.removeTag = function (tag)
        turtle.taggedPositions[tag] = nil;

        local tags = deserializePath(TAG_FILE_PATH);
        tags[tag] = nil;
        serializePath(TAG_FILE_PATH, tags);
    end

    -- load tags
    turtle.taggedPositions = deserializePath(TAG_FILE_PATH, function (_, v)
        local _, _, pos, dir = string.find(v, "(.+)|(.+)")
        pos = str2vec(pos);
        return {
            pos = pos,
            facing = dir
        };
    end);
end


