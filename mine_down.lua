dofile("/user/programs/utils.lua");
dofile("/user/programs/mine.lua");
dofile("/user/programs/fuel.lua");

args = {...}

function shouldMine()
    return fitsPattern("_ore");
end

function mineVeinMethod()
    TurtleMine.mineVein(function ()
        if TurtleFuel.needsRefueling(80) then
            TurtleFuel.refuel(2);
        end
    end, function (isNotAir, block)
        return isNotAir and shouldMine()(block.name)
    end)
end

local howFarDown = args[1];
howFarDown = howFarDown and tonumber(howFarDown) or math.huge;

local fastMode = args[2];
fastMode = fastMode and toboolean(fastMode) or true;

local stepCount = 0;

function tryMine(exists, block)
    if exists and shouldMine()(block.name) then
        mineVeinMethod();
        return true;
    else
        return false;
    end
end

while true do
    if stepCount >= howFarDown then break end;

    local exists, block = turtle.inspectDown();
    if exists then
        if not tryMine(exists, block) then
            if not turtle.digDown() then break end;
        end
    end
    turtle.down();

    if not fastMode then
        -- checking all four neighbouring blocks
        tryMine(turtle.inspect());
        turtle.turnRight();
        tryMine(turtle.inspect());
        turtle.turnRight();
        tryMine(turtle.inspect());
        turtle.turnRight();
        tryMine(turtle.inspect());
        turtle.turnRight();
    end

    stepCount = stepCount + 1;
end

while stepCount > 0 do
    turtle.digUp();
    turtle.up();
    stepCount = stepCount - 1;
end
