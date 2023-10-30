INV = {};

local function forEachItem(callback)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if item then
            local shouldBreak = callback(item, i);
            if shouldBreak then return shouldBreak end;
        end
    end
end

function INV.slotsEmpty()
    local count = 0;
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if item == nil then count = count + 1 end;
    end
    return count;
end

function INV.getTorchSlot()
    return INV.findFirstItem(function (name) return name == "minecraft:torch" end);
end

function INV.findFirstInInventory(inventory, filter)
    assert(inventory);
    filter = filter or function (_) return true end;

    for slot, item in pairs(inventory.list()) do
        if filter(item) then
            return slot, item;
        end
    end
end

function INV.findInInventory(inventory, filter)
    assert(inventory);
    filter = filter or function (_) return true end;
    local items = {};
    local totalCount = 0;

    for slot, item in pairs(inventory.list()) do
        if filter(item) then
            items[slot] = item;
            totalCount = totalCount + item.count;
        end
    end
    return totalCount, items;
end

local placeTransferChest = function ()
    local originalSlot = turtle.getSelectedSlot();

    local exists, block = turtle.inspectUp();
    if exists then
        -- chest already placed
        if block.name ~= "minecraft:chest" then
            print("Turtle must have one empty space above it for item transfer");
            turtle.select(originalSlot);
            return nil;
        end
    else
        -- have to place a new chest
        local internalChestSlot, _ = INV.findFirstItem(function (name) return name == "minecraft:chest"; end);
        if not internalChestSlot then
            print("Turtle needs to have a chest in its inventory for item transfer");
            return nil;
        end
        turtle.select(internalChestSlot);
        if not turtle.placeUp() then
            print("Turtle must have one empty space above it for item transfer");
            turtle.select(originalSlot);
            return nil;
        end
        turtle.select(originalSlot);
        os.sleep(0.1);
    end
    -- chest is definitely placed now
    local transferChest = peripheral.wrap("top");
    if not transferChest then
        print("Couldn't wrap transfer chest peripheral, destroying the chest");
        turtle.digUp();
        return nil;
    end
    return transferChest;
end

-- turtle needs a chest in its inventory for this
function INV.takeItems(inventory, nameMatcher, howMany, onItemsTransferred)
    assert(inventory);
    nameMatcher = nameMatcher or function (_) return true end;
    onItemsTransferred = onItemsTransferred or function () end;
    howMany = howMany or 64;

    if howMany == 0 then return 0 end;

    -- first we find the item we want in the peripheral inventory
    local totalCount, items = INV.findInInventory(inventory, function (item) return nameMatcher(item.name) end);
    if totalCount == 0 then return 0 end;

    -- place transfer chest
    local transferChest = placeTransferChest();
    if not transferChest then return 0 end;
    -- TODO: pull in any items remaining in the transfer chest

    local countTransferred = 0;

    for slot, _ in pairs(items) do
        local itemsToTake = howMany - countTransferred;
        local itemsTaken = inventory.pushItems("top", slot, itemsToTake);
        local sucked, error = turtle.suckUp(itemsTaken);
        if not sucked then
            print("Couldn't take items from transfer chest: " .. error);
            break;
        else
            countTransferred = countTransferred + itemsTaken;
            onItemsTransferred(countTransferred);
        end

        if countTransferred >= howMany then break end
    end
    -- we can now destroy the transfer chest
    turtle.digUp();
    return countTransferred;
end

-- turtle needs a chest in its inventory for this
function INV.takeAllItems(inventory, nameMatcher)
    assert(inventory);
    nameMatcher = nameMatcher or function (_) return true end;

    -- first get all the info about the items we want
    local totalCount, items = INV.findInInventory(inventory, function (item) return nameMatcher(item.name) end);
    if totalCount == 0 then
        return true;
    end

    -- the items exist so we can place the transfer chest
    local transferChest = placeTransferChest();
    if not transferChest then return false end

    for slot, item in pairs(items) do
        inventory.pushItems("top", slot);
        turtle.suckUp();
    end

    -- we can now destroy the transfer chest
    turtle.digUp();
    return true;
end

function INV.findFirstItem(nameMatcher)
    nameMatcher = nameMatcher or function (_) return true end;
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if item and nameMatcher(item.name) then
            return i, item;
        end
    end
    return nil;
end

local function turtleFace(where)
    if where == "left" then
        turtle.turnLeft();
    elseif where == "right" then
        turtle.turnRight();
    elseif where == "back" then
        turtle.turnRight();
        turtle.turnRight();
    end
end

local function turtleInvertTurn(where)
    if where == "left" then
        turtle.turnRight();
    elseif where == "right" then
        turtle.turnLeft();
    elseif where == "back" then
        turtle.turnRight();
        turtle.turnRight();
    end
end

local function turtlePlace(where)
    if where == "down" then return turtle.placeDown() end;
    if where == "up" then return turtle.placeUp() end;
    return turtle.place();
end

local function turtleDrop(where, howMany)
    if where == "down" then return turtle.dropDown(howMany) end;
    if where == "up" then return turtle.dropUp(howMany) end;
    return turtle.drop(howMany);
end

local function whileFacing(where, callback)
    turtleFace(where);
    local result = callback();
    turtleInvertTurn(where);
    return result;
end

local function withSelection(slot, callback)
    local originalSlot = turtle.getSelectedSlot();
    turtle.select(slot);
    local result = callback();
    turtle.select(originalSlot);
    return result;
end

function INV.place(nameMatcher, where)
    assert(nameMatcher);
    where = where or "front";
    local slot, _ = INV.findFirstItem(nameMatcher);
    if not slot then return false end;

    return whileFacing(where, function()
        return withSelection(slot, function()
            return turtlePlace(where);
        end);
    end);
end

function INV.dropAll(nameMatcher, where)
    nameMatcher = nameMatcher or function (_) return true end;
    local originalSlot = turtle.getSelectedSlot();
    local dropMethod = function () return turtleDrop(where) end;

    forEachItem(function (item, slot)
        if nameMatcher(item.name) then
            turtle.select(slot);
            dropMethod();
        end
    end)
    turtle.select(originalSlot);
    return true;
end

function INV.drop(nameMatcher, howMany, where)
    nameMatcher = nameMatcher or function (_) return true end;
    local originalSlot = turtle.getSelectedSlot();
    local dropMethod = function (count) return turtleDrop(where, count) end;
    local itemsRemaining = howMany or 1;

    forEachItem(function (item, slot)
        if nameMatcher(item.name) then
            turtle.select(slot);

            local itemsWereDropped, error = dropMethod(itemsRemaining);
            if not itemsWereDropped then
                print("Couldn't drop items froms slot " .. slot .. ": " .. error);
            end
            local updatedItem = turtle.getItemDetail(slot);
            local itemsActuallyDropped = updatedItem and (item.count - updatedItem.count) or item.count;
            itemsRemaining = itemsRemaining - itemsActuallyDropped;
            if itemsRemaining <= 0 then return true end
        end
    end);
    turtle.select(originalSlot);
    return {
        itemsDropped = howMany - itemsRemaining;
    }
end

-- refills an item type up to the full stack
function INV.refillFromInventory(inventory, nameMatcher, upTo)
    nameMatcher = nameMatcher or function (_) return true end;
    upTo = upTo or 64;

    local actualItemCount = INV.getTotalAmount(nameMatcher);
    if actualItemCount >= upTo then
        print("No need to refill yet");
        return true;
    end

    local howManyRemaining = upTo - actualItemCount;
    while howManyRemaining > 0 do
        local countTransferred = INV.takeFirstFromInventory(inventory, nameMatcher, howManyRemaining);
        if countTransferred == 0 then
            print("Inventory has no items to take");
            return false;
        end
        howManyRemaining = howManyRemaining - countTransferred;
    end
    return true;
end

function INV.getTotalAmount(nameMatcher)
    nameMatcher = nameMatcher or function (_) return true end;
    local count = 0;

    forEachItem(function(item, _)
        if nameMatcher(item.name) then
            count = count + item.count;
        end
    end);
    return count;
end

return INV;
