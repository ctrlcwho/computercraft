dofile("/user/programs/inventory_utils.lua");

--[[

Description:

Farms crops in a square

Legend:
W - water
C - crops
v, ^, <, > - turtle path
B - barrel
T - turtle idle position

Farm layout:

     CCCCC
     CCCCC
     CCWCC
     CCCCC
     CCCCC
     TB

--]]

FARM = {};

function FARM.crops(parameters)
    local bottomLeft = assert(parameters.bottomLeft);
    local topRight = assert(parameters.topRight);
    local tallCrops = parameters.tallCrops;

    -- these are for resuming the operation
    parameters.state = parameters.state or "prepareToHarvest";
    log("Parameters: \n" .. table.tostring(parameters));
    CMD.updateOwnState(parameters);

    local isSeeds = function (name)
        return fitsPattern("seed")(name)
                or name == "minecraft:carrot"
                or name == "minecraft:potato";
    end

    local STATES = {
        prepareToHarvest = prepareToHarvest,
        -- we determine the position at startup anyways, who cares if we miss one crop
        moveToNextCrop = moveToNextCrop,
        -- this just checks the crop, doesn't do anything special
        checkCrop = checkCrop,
        -- we can repeat planting just fine, nothings gonna break
        plantSeeds = plantSeeds,
        -- it shouldn't be replanted yet so theres no way we can break a newly planted crop, this is safe
        harvestCrop = harvestCrop,

        -- unsafe states
        -- switch lanes might be half way done, we cant tell
        switchLanes = noop,
    }

    function changeState(name)
        parameters.state = name;
        CMD.updateOwnState(parameters);
        printDebug("Changing state to " .. name);
        return STATES[name]();
    end

    function prepareToHarvest()
        turtle.up();
        if tallCrops then turtle.up() end;
        turtle.forward();
        return changeState("checkCrop");
    end

    local farm = boundingBox(bottomLeft, topRight, {
        atLeftEdge = function ()
            switchLanes("Right");
        end,
        atRightEdge = function ()
            switchLanes("Left");
        end,
        atCorner = function (x, z)
            if x == 1 then return true end;
            switchLanes("Right");
        end
    });

    function exceptionalState(action, msg)
        print(msg);
        -- repeats action until the problem resolves itself
        os.sleep(10);
        return action();
    end

    function switchLanes(direction)
        turtle["turn" .. direction]();
        turtle.forward();
        turtle["turn" .. direction]();
        printDebug("Checking crop after switching lanes");
        return changeState("checkCrop");
    end

    function plantSeeds()
        local seedSlot, _ = INV.findFirstItem(isSeeds);
        local originalSlot = turtle.getSelectedSlot();
        turtle.select(seedSlot);
        _ = tallCrops and turtle.down();
        turtle.placeDown();
        _ = tallCrops and turtle.up();
        turtle.select(originalSlot);
        printDebug("Planted seeds");

        return changeState("moveToNextCrop");
    end

    function moveToNextCrop()
        printDebug(vec2str(turtle.pos));
        local finished = farm.checkPosition(turtle.pos, turtle.facing);
        if finished then
            printDebug("finished farming");
            return;
        end;

        turtle.forward();

        return changeState("checkCrop");
    end

    function harvestCrop()
        turtle.digDown();
        printDebug("Harvested crop");
        return changeState("plantSeeds");
    end

    local CROP_STATES = {
        ["minecraft:wheat"] = 7,
        ["minecraft:carrots"] = 7,
        ["minecraft:potatoes"] = 7,
        ["supplementaries:flax"] = 7
    }

    function checkCrop()
        local exists, crop = turtle.inspectDown();
        if not exists then
            -- two block tall crops might be one block tall in early stages
            -- but we don't want to waste time and fuel going up and down, so the assumption is that the seeds are planted already
            if not tallCrops then
                return changeState("plantSeeds");
            else
                return changeState("moveToNextCrop");
            end
        else
            local grownState = CROP_STATES[crop.name];
            if not grownState then
                return exceptionalState(checkCrop, "Crop " .. crop.name .. " is unknown, register its grown state in the code");
            end
            if crop.state.age == grownState then
                return changeState("harvestCrop");
            else
                return changeState("moveToNextCrop");
            end
        end
    end

    STATES[parameters.state]();

end










