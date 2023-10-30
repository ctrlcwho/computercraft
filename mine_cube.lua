dofile("/user/programs/mine.lua");
dofile("/user/programs/fuel.lua");
dofile("/user/programs/utils.lua");

args = {...}

local xdim = args[1]; -- forward
local ydim = args[2]; -- up
local zdim = args[3]; -- right

if not xdim or not ydim or not zdim then
    error("Please specify three dimensions of the cube to mine");
end

xdim = tonumber(xdim);
ydim = tonumber(ydim);
zdim = tonumber(zdim);

local right = zdim > 0;
local up = ydim > 0;

xdim = math.abs(xdim);
ydim = math.abs(ydim);
zdim = math.abs(zdim);

if xdim == 0 or ydim == 0 or zdim == 0 then
    error("Dimensions cannot be 0");
end

local totalBlocksToMine = xdim * ydim * zdim;
local fuelRequired = totalBlocksToMine - turtle.getFuelLevel();

if fuelRequired > 0 then
    if not TurtleFuel.refuel(fuelRequired) then
        error("Not enough fuel to mine all " .. tostring(totalBlocksToMine) .. " blocks");
    end
end

local laneNumber = 1;
local levelNumber = 1;

function switchLanes()
    local direction = right and "Right" or "Left";

    -- turn right once, dig and turn right (direction of mining is inverted)
    turtle["turn" .. direction]();
    turtle.dig();
    turtle.forward();
    turtle["turn" .. direction]();
    right = not right;

    return mineStrip();
end

function switchLevels()
    local digDirection = up and "Up" or "Down";
    local direction = string.lower(digDirection);

    -- dig and go down one level (direction of mining is inverted)
    turtle["dig" .. digDirection]();
    turtle[direction]();
    turtle.turnRight();
    turtle.turnRight();

    return mineStrip();
end

function returnToBase()
    print("TODO: return to base");
    return noop();
end

function mineStrip()
    for i = 1, (xdim - 1) do
        turtle.dig();
        turtle.forward();
    end

    if laneNumber == zdim then
        -- done with this level, switching levels
        if levelNumber == ydim then
            -- done digging
            return returnToBase();
        end
        laneNumber = 1;
        levelNumber = levelNumber + 1;
        return switchLevels();
    else
        -- not done with the level, switching switchLanes
        laneNumber = laneNumber + 1;
        return switchLanes();
    end
end

turtle.dig();
turtle.forward();

mineStrip();
