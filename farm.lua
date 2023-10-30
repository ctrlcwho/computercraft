dofile("/user/programs/fuel.lua")
dofile("/user/programs/inventory.lua")
dofile("/user/programs/utils.lua");

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

args = {...}

xdim = assert(args[1], "Must specify the X direction limit");
zdim = assert(args[2], "Must specify the Z direction limit");
tallCrops = args[3] or "false";
continueWork = args[4] or "false";
debug = args[5] or "false";

print("length: " .. xdim);
print("width: " .. zdim);
print("tall crops?: " .. tallCrops);
print("Continuing work?: " .. continueWork);

xdim = tonumber(xdim);
zdim = tonumber(zdim);
tallCrops = "true" == tallCrops;
continueWork = "true" == continueWork;
debug = "true" == debug;

function printDebug(msg)
    if debug then
        print("[DEBUG] " .. msg);
    end
end

local isChest = fitsPattern("minecraft:chest");
local isBarrel = fitsPattern("barrel");
local isCharcoal = fitsPattern("charcoal");
local isSeeds = function (name)
    return fitsPattern("seed")(name)
            or name == "minecraft:carrot"
            or name == "minecraft:potato";
end
local isCrop = function (name)
    return name == "minecraft:wheat"
            or name == "minecraft:carrot"
            or name == "minecraft:potato"
            or name == "supplementaries:flax";
end

local isCropOrSeeds = function (name)
    return isCrop(name) or isSeeds(name);
end

local chestSlot, chests = TurtleInv.findFirstItem(isChest);
assert(chestSlot and chests.count >= 1, "Cannot build farm without one chest in the inventory");

local blockNumber = 1;
local laneNumber = 1;

-- initial state
function refill()
    local input = peripheral.wrap("right");
    TurtleInv.refillFromInventory(input, isCharcoal, 64);
    printDebug("Refilled inventory at base");

    if TurtleFuel.needsRefueling(300) then
        if not TurtleFuel.refuel(4) then
            return exceptionalState(refill, "[ERROR] No fuel!");
        end
    end

    -- go above the crops
    turtle.up();
    if tallCrops then turtle.up() end;
    turtle.forward();
    checkCrop();
end

function exceptionalState(action, msg)
    print(msg);
    -- repeats action until the problem resolves itself
    os.sleep(10);
    return action();
end

function switchLanes()
    local direction = (laneNumber % 2 == 1) and "Right" or "Left";
    turtle["turn" .. direction]();
    turtle.forward();
    turtle["turn" .. direction]();
    laneNumber = laneNumber + 1;
    blockNumber = 1;
    printDebug("Checking crop after switching lanes");

    return checkCrop();
end

function plantSeeds()
    local seedSlot, _ = TurtleInv.findFirstItem(isSeeds);
    local originalSlot = turtle.getSelectedSlot();
    turtle.select(seedSlot);
    _ = tallCrops and turtle.down();
    turtle.placeDown();
    _ = tallCrops and turtle.up();
    turtle.select(originalSlot);
    printDebug("Planted seeds");

    return moveToNextCrop();
end

function dumpItems()
    turtle.turnRight();
    TurtleInv.dumpItems(isCropOrSeeds);
    turtle.turnLeft();
    printDebug("Dumped items");

    -- now wait before checking crops again
    os.sleep(600);
    laneNumber = 1;
    blockNumber = 1;
    return refill();
end

function returnToBase()
    if laneNumber % 2 == 1 then
        -- turtle is facing away from base
        turtle.turnRight();
        turtle.turnRight();
        for i = 1, (xdim - 1) do
            turtle.forward();
        end
    end

    -- turtle is in the lower right corner, must move to lower left
    turtle.turnRight();
    for i = 1, (zdim - 1) do
        turtle.forward();
    end
    turtle.turnRight();
    turtle.back();
    turtle.down();
    _ = tallCrops and turtle.down();
    printDebug("Returned to base");

    return dumpItems();
end

function moveToNextCrop()
    printDebug(tostring(blockNumber) .. ", " .. tostring(laneNumber));
    if blockNumber == xdim then
        -- done with this lane, switch it
        if laneNumber == zdim then
            -- done with checking crops
            return returnToBase();
        end
        return switchLanes();
    end
    blockNumber = blockNumber + 1;
    turtle.forward();
    return checkCrop();
end

function harvestCrop()
    turtle.digDown();
    printDebug("Harvested crop");
    return plantSeeds();
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
            return plantSeeds();
        else
            return moveToNextCrop();
        end
    else
        local grownState = CROP_STATES[crop.name];
        if not grownState then
            return exceptionalState(checkCrop, "Crop " .. crop.name .. " is unknown, register its grown state in the code");
        end
        if crop.state.age == grownState then
            return harvestCrop();
        else
            return moveToNextCrop();
        end
    end
end

if not continueWork then
    local originalSlot = turtle.getSelectedSlot();
    local barrelSlot, _ = TurtleInv.findFirstItem(isBarrel);
    turtle.turnRight();
    turtle.select(barrelSlot);
    turtle.place();
    turtle.turnLeft();
    turtle.select(originalSlot);
end

refill();












