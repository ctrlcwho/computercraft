dofile("/user/programs/fuel.lua");
dofile("/user/programs/inventory.lua");
dofile("/user/programs/utils.lua");

args = {...}

fillerBlock = assert(args[1], "Specify a filler block");
length = args[2] or "16";
width = args[3] or "1";
options = args[4] or "";

length = tonumber(length);
width = tonumber(width);
placeRailings = string.find(options, "railings");

local stepNumber = 1;

function stepForward()
    if TurtleFuel.needsRefueling(20) then
        if not TurtleFuel.refuel(1) then
            return error("Out of fuel!");
        end
    end

    turtle.dig();
    turtle.forward();
    turtle.digUp();

    stepNumber = stepNumber + 1;
    if stepNumber == length then
        return noop();
    else
        return buildBridge();
    end
end

function selectFiller()
    local slot, _ = TurtleInv.findFirstItem(fitsPattern(fillerBlock));
    if not slot then return false end;
    return turtle.select(slot);
end

function place()
    return genericPlace(turtle.place, turtle.inspect);
end

function placeDown()
    return genericPlace(turtle.placeDown, turtle.inspectDown);
end

function genericPlace(method, inspectMethod)
    local exists, _ = inspectMethod();
    if exists then
        -- no need to place, bridge exists
        -- TODO: optionally destroy block and replace it
        return
    end;

    local originalSlot = turtle.getSelectedSlot();
    local selectedItem = turtle.getItemDetail(originalSlot);
    if (selectedItem == nil or not fitsPattern(fillerBlock)(selectedItem.name)) and not selectFiller() then
        -- select filler only if the selected item is not the filler block or nothing is selected
        -- we quit if there is no more filler blocks
        return error("Out of filler!");
    end

    if not method() then
        return error("Why did placing fail? There should be no block under this turtle.");
    end
end

local invertDirection = false;
local turntable = {
    [true] = turtle.turnRight,
    [false] = turtle.turnLeft
}

local thickBridge = width > 1;

function buildBridge()
    placeDown();

    if placeRailings then
        turntable[invertDirection]();
        place();
        turntable[not invertDirection]();
    end

    if thickBridge then
        turntable[not invertDirection]();
        for i = 1, (width - 1) do
            turtle.dig();
            turtle.forward();
            turtle.digUp();
            placeDown();
        end
        -- (*) dont waste time turning if we need to turn to place a railing anyways
        if not placeRailings then turntable[invertDirection]() end;
    end
    invertDirection = not invertDirection;

    if placeRailings then
        -- we dont need to turn here because the previous turn was not reversed (goto *)
        if not thickBridge then turntable[invertDirection]() end;
        place();
        turntable[not invertDirection]();
    end

    return stepForward();
end

buildBridge();