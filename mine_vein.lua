dofile("/user/programs/mine.lua");
dofile("/user/programs/fuel.lua");
dofile("/user/programs/utils.lua");

args = {...}

local direction = args[2] or "forward";
local blocks = args[1];
local inspectMethod = nil;

if direction == "forward" then
    inspectMethod = turtle.inspect;
elseif direction == "up" then
    inspectMethod = turtle.inspectUp;
elseif direction == "down" then
    inspectMethod = turtle.inspectDown;
elseif direction == "left" then
    inspectMethod = function() turtle.turnLeft(); return turtle.inspect(); end
elseif direction == "right" then
    inspectMethod = function() turtle.turnRight(); return turtle.inspect(); end
end

local turtleFacingABlock, firstBlock = inspectMethod();
if not turtleFacingABlock then return error("Turtle facing air, place it facing any block to start mining") end;

TurtleMine.mineVein(function ()
    if TurtleFuel.needsRefueling(80) then
        TurtleFuel.refuel(2);
    end
end, function (isNotAir, block)
    if not isNotAir then return false end;

    if blocks then
        for blockPattern in string.gmatch(blocks, "([^,]+)") do
            if fitsPattern(blockPattern)(block.name) then return true end;
        end
    else
        return block.name == firstBlock.name;
    end
    return false;
end)
