TurtleInv = {};

function TurtleInv.slotsEmpty()
	local count = 0;
	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		if item == nil then count = count + 1 end;
	end
	return count;
end

function TurtleInv.getTorchSlot()
	return TurtleInv.findFirstItem(function (name) return name == "minecraft:torch" end);
end

function TurtleInv.findInInventory(inventory, filter)
	assert(inventory);
	filter = filter or function (_) return true end;

	for slot, item in pairs(inventory.list()) do
		if filter(item) then
			return slot, item;
		end
	end
end

function TurtleInv.findItemsInInventory(inventory, filter, mapper)
	assert(inventory);
	filter = filter or function (_) return true end;
	mapper = mapper or function (item) return item end;
	local items = {};
	local howMany = 0;

	for slot, item in pairs(inventory.list()) do
		if filter(item) then
			items[slot] = mapper(item);
			howMany = howMany + 1;
		end
	end
	return howMany, items;
end

local placeTransferChest = function ()
	local originalSlot = turtle.getSelectedSlot();
	local internalChestSlot, _ = TurtleInv.findFirstItem(function (name) return name == "minecraft:chest"; end);
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

	local transferChest = peripheral.wrap("top");
	if not transferChest then
		print("Couldn't wrap transfer chest peripheral, destroying the chest");
		turtle.digUp();
		return nil;
	end
	return transferChest;
end

-- turtle needs a chest in its inventory for this
function TurtleInv.takeFirstFromInventory(inventory, nameMatcher, howMany)
	assert(inventory);
	nameMatcher = nameMatcher or function (_) return true end;
	howMany = howMany or 64;

	-- first we find the item we want in the peripheral inventory
	local stackCount, items = TurtleInv.findItemsInInventory(inventory, function (item) return nameMatcher(item.name) end);
	if stackCount == 0 then return 0 end;
	local slot, item = pairs(items)(items);

	-- the item exists so now we place the transfer chest
	local transferChest = placeTransferChest();
	if not transferChest then return false end

	-- now we move the item from the inventory to the transfer chest
	local countTransferred = inventory.pushItems("top", slot, howMany);
	-- and then we suck it from the transfer chest to the turtle
	turtle.suckUp();

	-- we can now destroy the transfer chest
	turtle.digUp();
	return countTransferred;
end

-- turtle needs a chest in its inventory for this
function TurtleInv.takeAllFromInventory(inventory, nameMatcher)
	assert(inventory);
	nameMatcher = nameMatcher or function (_) return true end;

	-- first get all the info about the items we want
	local stackCount, items = TurtleInv.findItemsInInventory(inventory, function (item) return nameMatcher(item.name) end);
	if stackCount == 0 then
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

function TurtleInv.findFirstItem(nameMatcher)
	nameMatcher = nameMatcher or function (_) return true end;
	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		if item and nameMatcher(item.name) then
			return i, item;
		end
	end
	return nil;
end

local function turtlePlace(where)
	if where == "front" then
		turtle.place();
	elseif where == "left" then
		turtle.turnLeft();
		turtle.place();
		turtle.turnRight();
	elseif where == "right" then
		turtle.turnRight();
		turtle.place();
		turtle.turnLeft();
	elseif where == "back" then
		turtle.turnRight();
		turtle.turnRight();
		turtle.place();
		turtle.turnRight();
		turtle.turnRight();
	elseif where == "up" then
		turtle.placeUp();
	elseif where == "down" then
		turtle.placeDown();
	else
		return error("Incorrect placement direction " .. where);
	end
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

local dropMethods = {
	down = turtle.dropDown,
	up = turtle.dropUp
};

local placeMethods = {
	down = turtle.placeDown,
	up = turtle.placeUp
};

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

function TurtleInv.dumpItemsInAChest(nameMatcher, chestPlacement, chestItemSelector)
	nameMatcher = nameMatcher or function (_) return true end;
	chestItemSelector = chestItemSelector or function (name) return name == "minecraft:chest" end;
	chestPlacement = chestPlacement or "down";
	local slot, _ = TurtleInv.findFirstItem(chestItemSelector);
	if not slot then return false; end

	-- place the chest in the specified place
	return whileFacing(chestPlacement, function ()
		local couldPlace = withSelection(slot, function ()
			local placeMethod = placeMethods[chestPlacement] or turtle.place;
			return placeMethod();
		end);

		-- dump the items
		if not couldPlace then return false; end
		return TurtleInv.dumpItems(nameMatcher, dropMethods[chestPlacement] or turtle.drop);
	end);
end

function TurtleInv.dumpItems(nameMatcher, dropFunction)
	nameMatcher = nameMatcher or function (_) return true end;
	dropFunction = dropFunction or turtle.drop;
	local originalSlot = turtle.getSelectedSlot();

	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		if item and nameMatcher(item.name) then
			turtle.select(i);
			if not dropFunction() then
				turtle.select(originalSlot);
				return false;
			end
		end
	end
	turtle.select(originalSlot);
	return true;
end

-- refills an item type up to the full stack
function TurtleInv.refillFromInventory(inventory, nameMatcher, upTo)
	nameMatcher = nameMatcher or function (_) return true end;
	upTo = upTo or 64;

	local actualItemCount = TurtleInv.getTotalAmount(nameMatcher);
	if actualItemCount >= upTo then
		print("No need to refill yet");
		return true;
	end

	local howManyRemaining = upTo - actualItemCount;
	while howManyRemaining > 0 do
		local countTransferred = TurtleInv.takeFirstFromInventory(inventory, nameMatcher, howManyRemaining);
		if countTransferred == 0 then
			print("Inventory has no items to take");
			return false;
		end
		howManyRemaining = howManyRemaining - countTransferred;
	end
	return true;
end

function TurtleInv.compact()
	local items = {};

	-- first collect data about item counts and slots
	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		-- stores only non-full stacks
		if item and not turtle.getItemSpace() == 0 then
			items[item.name] = items[item.name] or {};
			table.insert(items[item.name], {slot = i, count = item.count});
		end
	end

	-- then try to compact the stacks to the first slot found
	for name, entries in pairs(items) do
		local firstEntry = nil;

		for i, entry in ipairs(entries) do
			-- ignores the first entry as this is the one which will accumulate the items
			if firstEntry == nil then
				firstEntry = entry;
			else
				-- TODO: this will get kind of difficult when we fill up one stack and have to start filling another
				--       a simpler solution might be to just dump all the items into a chest and then take them again
			end
		end
	end
end

function TurtleInv.getTotalAmount(nameMatcher)
	nameMatcher = nameMatcher or function (_) return true end;
	local count = 0;

	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		if item and nameMatcher(item.name) then
			count = count + item.count;
		end
	end
	return count;
end

return TurtleInv;
