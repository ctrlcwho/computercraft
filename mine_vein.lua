dofile("/user/programs/mine.lua");
dofile("/user/programs/fuel.lua");

args = {...}

local direction = args[1] or "forward";
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
    return isNotAir and block.name == firstBlock.name;
end)
