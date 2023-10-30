dofile("/user/programs/fuel.lua")
dofile("/user/programs/inventory.lua")
dofile("/user/programs/utils.lua");


--[[

Description:

Basically farms wood automatically, the input barrel must be constantly supplied with saplings and fuel though,
this can be done with some item transport system that smelts some of the logs into charcoal and dumps the surplus
saplings, this will create a self sustaining farm.

Legend:
L - log
S - sapling
v, ^, <, > - turtle path
I - input barrel
O - output barrel
T - turtle idle position

Farm layout:
     S....L....S....S....L
     ^>>>>^>>>>^>>>>^>>>>^
     ^
     ^
    ITO

- The input barrel takes saplings and coal/charcoal for the turtle to use
- The output barrel is supplied with logs

--]]

args = {...}

treeCount = assert(args[1], "Must specify a tree count (how many trees will be planted)");
treeSpacing = args[2] or 4;
continueWork = args[3] or "false";
debug = args[4] or "false";

print("Tree count: " .. treeCount);
print("Tree spacing: " .. treeSpacing);
print("Continuing work?: " .. continueWork);

treeCount = tonumber(treeCount);
treeSpacing = tonumber(treeSpacing);
continueWork = "true" == continueWork;
debug = "true" == debug;

function printDebug(msg)
    if debug then
        print("[DEBUG] " .. msg);
    end
end

-- todo hardcoded for now
farmDistance = 3;

if turtle.detect() then
    error("Turtle needs at least one space in front of it to start farming");
end
if turtle.detectUp() then
    error("Turtle needs one space above it for transferring items");
end

local isLog = fitsPattern("log");
local isSapling = fitsPattern("sapling");
local isChest = fitsPattern("minecraft:chest");
local isBarrel = fitsPattern("barrel");
local isCharcoal = fitsPattern("charcoal");

local chestSlot, chests = TurtleInv.findFirstItem(isChest);
assert(continueWork or chestSlot and chests.count >= 1, "Cannot build farm without one chest in the inventory");

local barrelSlot, barrels = TurtleInv.findFirstItem(isBarrel);
assert(continueWork or barrelSlot and barrels.count >=2, "Cannot build farm without two barrels in the inventory");

local saplingSlot, saplings = TurtleInv.findFirstItem(isSapling);
assert(continueWork or saplingSlot and saplings.count >= treeCount);

local currentTreeStep = 0;

-- initial state
function refill()
    local input = peripheral.wrap("left");
    TurtleInv.refillFromInventory(input, isSapling, 64);
    TurtleInv.refillFromInventory(input, isCharcoal, 64);
    printDebug("Refilled inventory at base");

    if TurtleFuel.needsRefueling(300) then
        if not TurtleFuel.refuel(4) then
            return exceptionalState(refill, "[ERROR] No fuel!");
        end
    end

    return dumpLogs();
end

function dumpLogs()
    turtle.turnRight();
    TurtleInv.dumpItems(isLog);
    turtle.turnLeft();
    printDebug("Dumped logs at base");

    return approachTreeLine();
end

function replantSapling()
    saplingSlot, saplings = TurtleInv.findFirstItem(isSapling);
    turtle.select(saplingSlot);
    turtle.place();
    printDebug("Replanted sapling");

    return tryCheckingNextTree();
end

function moveToNextTree()
    turtle.turnRight();
    for i = 1, (treeSpacing + 1) do
        if not turtle.forward() then
            exceptionalState(moveToNextTree, "Path blocked!");
        end
    end
    turtle.turnLeft();
    currentTreeStep = currentTreeStep + 1;
    printDebug("Moving to next tree, step = " .. tostring(currentTreeStep));

    return getTreeState();
end

function backtrackToBase()
    printDebug("Backtracking to base");
    currentTreeStep = 0;
    local totalFarmLength = (treeCount - 1) * (treeSpacing + 1);
    turtle.turnLeft();
    for i = 1, totalFarmLength do turtle.forward(); turtle.dig(); end
    turtle.turnLeft();
    for i = 1, farmDistance do turtle.forward(); turtle.dig(); end
    turtle.turnRight();
    turtle.turnRight();
    printDebug("Back at base");

    -- wait for a while and repeat the process indefinitely
    os.sleep(60)
    return refill();
end

function harvestTree()
    -- in front of tree
    turtle.dig();
    turtle.forward();

    -- at tree base now
    local blockAboveExists, blockAbove = turtle.inspectUp();
    while blockAboveExists and isLog(blockAbove.name) do
        turtle.digUp();
        turtle.up();
        blockAboveExists, blockAbove = turtle.inspectUp();
    end

    -- entire tree harvested, going back down
    local blockBelowExists, blockBelow = turtle.inspectDown();
    while not blockBelowExists do
        turtle.down();
        blockBelowExists, blockBelow = turtle.inspectDown();
    end

    -- NOTE: due to the auto replanting mod, a sapling can get planted where the tree was, we need to handle that
    if isSapling(blockBelow.name) then
        turtle.digDown();
        turtle.down();
    end

    turtle.back();
    return tryCheckingNextTree();
end

function tryCheckingNextTree()
    if currentTreeStep == (treeCount - 1) then
        return backtrackToBase();
    else
        return moveToNextTree();
    end
end

function exceptionalState(action, msg)
    print(msg);
    -- repeats action until the problem resolves itself
    os.sleep(10);
    return action();
end

function getTreeState()
    local exists, baseBlock = turtle.inspect();
    printDebug("Base tree block is " .. (exists and baseBlock.name or "nil"));
    if not exists then
        return replantSapling();
    elseif isSapling(baseBlock.name) then
        return tryCheckingNextTree();
    elseif isLog(baseBlock.name) then
        return harvestTree();
    else
        return exceptionalState(getTreeState, "[ERROR] Tree space obstructed by " .. baseBlock.name);
    end
end

function setupBase()
    turtle.select(barrelSlot);

    turtle.turnLeft();
    if turtle.detect() then turtle.dig() end;
    turtle.place();

    turtle.turnRight();
    turtle.turnRight();
    if turtle.detect() then turtle.dig() end;
    turtle.place();
    turtle.turnLeft();
end

function approachTreeLine()
    for i = 1, farmDistance do
        turtle.dig();
        turtle.forward();
    end
    printDebug("I am at the first tree right now");

    return getTreeState();
end

-- farm setup
if not continueWork then
    -- place the input and output barrels
    setupBase();

    -- clear out space for the farm
    for i = 1, farmDistance do
        turtle.dig();
        turtle.forward();
    end

    for i = 1, farmDistance do
        turtle.back();
    end
end

refill();
