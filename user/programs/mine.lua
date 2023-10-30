TurtleMine = {};

TurtleMine.oreNames = {
    ["minecraft:coal_ore"] = true,
    ["minecraft:diamond_ore"] = true,
    ["minecraft:iron_ore"] = true,
    ["minecraft:gold_ore"] = true,
    ["minecraft:lapis_ore"] = true,
    ["minecraft:redstone_ore"] = true,
    ["minecraft:emerald_ore"] = true,
    ["minecraft:copper_ore"] = true,
    ["minecraft:deepslate_coal_ore"] = true,
    ["minecraft:deepslate_diamond_ore"] = true,
    ["minecraft:deepslate_iron_ore"] = true,
    ["minecraft:deepslate_gold_ore"] = true,
    ["minecraft:deepslate_lapis_ore"] = true,
    ["minecraft:deepslate_redstone_ore"] = true,
    ["minecraft:deepslate_emerald_ore"] = true,
    ["minecraft:deepslate_copper_ore"] = true
};

function TurtleMine.isOre(exists, block)
    return exists and TurtleMine.oreNames[block.name];
end

function TurtleMine.oneByOneTunnel(args)
    local distance = args.distance;
    local stopCondition = args.stopCondition;
    local onStop = args.onStop or function () end;

    assert(distance);
    assert(stopCondition);

    for i = 1, distance do
        local exists, block = turtle.inspect();
        local shouldStop, reason = stopCondition(exists, block);
        if shouldStop then
            return onStop(reason, i);
        end

        turtle.dig();
        if not turtle.forward() then return onStop("move_failed") end;
    end
    return onStop("done");
end

function TurtleMine.tunnelForward(args)
    local distance = args.distance;
    local stopCondition = args.stopCondition;
    local onStop = args.onStop or function () end;
    local onMove = args.onMove or function () end;
    local oneByOne = args.oneByOne or false;

    assert(distance);
    assert(stopCondition);

    for i = 1, distance do
        local exists, block = turtle.inspect();
        if stopCondition(exists, block) then
            return onStop(exists, block);
        end

        turtle.dig();
        if not turtle.forward() then return onStop() end;
        if not onMove(i - 1) then return onStop() end;

        if not oneByOne then
            exists, block = turtle.inspectUp();
            if stopCondition(exists, block) then
                return onStop(exists, block);
            end
            turtle.digUp();
        end
    end
    return onStop();
end

function TurtleMine.tunnelDown(args)
    local distance, stopCondition, onStop = unpack(args);
    assert(distance);
    assert(stopCondition);
    onStop = onStop or function () end;

    for i = 0, distance do
        if stopCondition() then
            return onStop();
        end

        turtle.digDown();
        turtle.down();
    end
end

-- will try mining ore vein in front of it till it's exhausted
function TurtleMine.mineVein(onBlockMined, shouldMine)
    print("Mining vein...");
    onBlockMined = onBlockMined or function () end;
    shouldMine = shouldMine or TurtleMine.isOre;

    local previousMove = nil;
    local movements = {};
    local reverseMovements = {
        ["forward"] = "back",
        ["back"] = "forward",
        ["turnLeft"] = "turnRight",
        ["turnRight"] = "turnLeft",
        ["up"] = "down",
        ["down"] = "up"
    };

    local moveTurtle = function (movement)
        turtle[movement]();
        table.insert(movements, movement);
        previousMove = movement;
        print("moving (" .. movement .. ")");
    end

    local backtrackTurtle = function ()
        if #movements == 0 then
            return false;
        end
        local lastMove = table.remove(movements);
        local reverseMove = reverseMovements[lastMove];

        turtle[reverseMove]();
        previousMove = reverseMove;
        print("backtracking (" .. reverseMove .. ")");
        return true;
    end

    local findOre = function ()
        local moveAndDigForward = function () turtle.dig(); moveTurtle("forward"); end;
        local roundTrip = function ()
            turtle.turnLeft();
            if shouldMine(turtle.inspect()) then
                -- 90 degrees
                table.insert(movements, "turnLeft");
                return moveAndDigForward;
            end
            turtle.turnLeft();
            if shouldMine(turtle.inspect()) then
                -- 180 degrees
                table.insert(movements, "turnLeft");
                table.insert(movements, "turnLeft");
                return moveAndDigForward;
            end
            turtle.turnLeft();
            if shouldMine(turtle.inspect()) then
                -- 270 degrees (equivalent to -90 degrees)
                table.insert(movements, "turnRight");
                return moveAndDigForward;
            end
            -- 360 degrees
            turtle.turnLeft();
        end

        if previousMove ~= "back" and shouldMine(turtle.inspect()) then
            return moveAndDigForward;
        elseif previousMove ~= "down" and shouldMine(turtle.inspectUp()) then
            return function () turtle.digUp(); moveTurtle("up"); end;
        elseif previousMove ~= "up" and shouldMine(turtle.inspectDown()) then
            return function () turtle.digDown(); moveTurtle("down"); end;
        elseif previousMove == nil or previousMove == "back" or previousMove == "up" or previousMove == "down" or previousMove == "forward" then
            return roundTrip();
        end
    end

    while true do
        local digAction = findOre();

        -- if no ore was found, we need to backtrack and check again,
        -- if we can't backtrack anymore then the entire vein was mined
        if digAction == nil then
            if not backtrackTurtle() then break end;
        else
            -- ore was found, so we mine it and move in its position and call the callback parameter
            digAction();
            onBlockMined();
        end
    end
    print("... done mining vein");
end

return TurtleMine;
