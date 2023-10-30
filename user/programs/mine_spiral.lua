dofile("/user/programs/fuel.lua")
dofile("/user/programs/inventory.lua")
dofile("/user/programs/mine.lua")

args = {...};

cycles = args[1] or 10;

distanceToTravel = 1;
distanceLeftToTravel = distanceToTravel;

tunnelMethod = nil;

mineVeinMethod = function () return TurtleMine.mineVein(
        function ()
            if TurtleFuel.needsRefueling(80) then
                TurtleFuel.refuel(2);
            end
        end,
        TurtleMine.isOre
) end;

tunnelMethod = function () TurtleMine.tunnelForward{
    distance = distanceLeftToTravel,

    stopCondition = function (exists, block)
        -- stops if it detects ore
        return TurtleMine.isOre(exists, block);
    end,

    onStop = function (exists, block)
        mineVeinMethod();


        -- recursively continue tunneling after mining an ore vein
        print("Finished mining ore, tunneling for another " .. distanceLeftToTravel .. " blocks");
        return tunnelMethod();
    end,

    onMove = function (distanceMoved)
        distanceLeftToTravel = distanceLeftToTravel - 1;
        if distanceLeftToTravel == 0 then
            -- finished this tunnel, turn right and tunnel more
            distanceToTravel = distanceToTravel + 1;
            distanceLeftToTravel = distanceToTravel;
            turtle.turnRight();
            print("Tunneling finished, turning right and resuming now");
        end
        -- check for ores on each move
        mineVeinMethod();
        return true;
    end
} end

return tunnelMethod();

