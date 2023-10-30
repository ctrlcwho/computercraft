dofile("/user/programs/fuel.lua");
dofile("/user/programs/inventory.lua");
dofile("/user/programs/mine.lua");

args = {...}

tunnelLength = args[1] or "16";
cycles = args[2] or "8"

tunnelLength = tonumber(tunnelLength);
cycles = tonumber(cycles);

if tunnelLength < 0 then return error() end;
if cycles < 0 then return error() end;
if cycles % 2 ~= 0 then return error("cycles should be divisible by 2 so that the turtle can return safely") end

print("digging " .. tostring(tunnelLength) .. " block long tunnels for " .. tostring(cycles) .. " cycles");

local stepNumber = 1;
local laneNumber = 1;

function switchLanes()
    if laneNumber == cycles then
        return returnToBase();
    end

    local rightOrLeft = laneNumber % 2 == 1 and "Right" or "Left";
    turtle["turn" .. rightOrLeft]();
    turtle.dig();
    turtle.forward();
    turtle.dig();
    turtle.forward();
    turtle.dig();
    turtle.forward();
    turtle["turn" .. rightOrLeft]();

    laneNumber = laneNumber + 1;
    stepNumber = 1;
    return stepForward();
end

function mineOre()
    TurtleMine.mineVein();
    return stepForward();
end

function checkForOre()
    if TurtleMine.isOre(turtle.inspect())
        or TurtleMine.isOre(turtle.inspectUp())
        or TurtleMine.isOre(turtle.inspectDown()) then

        return mineOre();
    end
    return stepForward();
end

function dumpItems()

end

function returnToBase()
    -- should be a straight way to the base now
    turtle.turnRight();

end

function clearTopAndBottomBlocks()
    turtle.digUp();
    turtle.digDown();
end

function stepForward()
    turtle.dig();
    turtle.forward();
    stepNumber = stepNumber + 1;

    if stepNumber == tunnelLength then
        return switchLanes();
    end

    -- now is the best time to check for ore because the turtle is exposed to five different blocks
    return checkForOre();
end

-- TODO: finish this program

tunnelMethod = function () TurtleMine.oneByOneTunnel{
    distance = distanceLeftToTravel,

    stopCondition = function (exists, block)
        -- stops if it detects ore
        if TurtleMine.isOre(exists, block) then
            return true, "ore_found";
        end

        -- (side effect) check for ores if no other condition was fulfilled
        mineVeinMethod();

        return false;
    end,

    onStop = function (reason, i)

        if reason == "done" then
            cyclesLeft = cyclesLeft - 1;
            if cyclesLeft == 0 then
                returnToBaseMethod();
                return;
            end

            -- turtle is now at the end of an even cycle so we check if there's enough fuel,
            -- if there's not enough fuel then we can safely and easily return to base
            if not movingAwayFromBase and TurtleFuel.needsRefueling(80) then
                if not TurtleFuel.refuel(2) then
                    returnToBaseMethod();
                    return;
                end
            end

            if movingAwayFromBase then turtle.turnRight() else turtle.turnLeft() end;
            -- TODO: not detecting ores here, fix it sometime
            -- this makes tunnels with 2 blocks in between for optimal ore yield
            turtle.dig();
            turtle.forward();
            turtle.dig();
            turtle.forward();
            turtle.dig();
            turtle.forward();
            if movingAwayFromBase then turtle.turnRight() else turtle.turnLeft() end;

            -- even cycle numbers are going away from base
            movingAwayFromBase = (cycles - cyclesLeft) % 2 == 0;

            distanceLeftToTravel = tunnelLength;
            return tunnelMethod();
        elseif reason == "ore_found" then
            -- should mine ore and continue tunneling
            mineVeinMethod();
            distanceLeftToTravel = tunnelLength - i;
            print("Resuming tunneling for another " .. distanceLeftToTravel .. " blocks");
            return tunnelMethod();
        else
            print("Unknown stop reason " .. reason);
        end
    end
} end

return tunnelMethod();