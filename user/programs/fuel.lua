TurtleFuel = {};

function TurtleFuel.needsRefueling(limit)
	return turtle.getFuelLevel() < limit;
end

function TurtleFuel.refuel(n)
	n = n or 1;
	local selectedSlot = turtle.getSelectedSlot();
	local maxRefuelCount;
	
	for i = 1, 16 do
		local item = turtle.getItemDetail(i);
		
		if item and string.find(item.name, "coal") then
			maxRefuelCount = math.min(n, item.count);
			print("refueling by " .. tostring(maxRefuelCount));
			turtle.select(i);
			turtle.refuel(maxRefuelCount);
			turtle.select(selectedSlot);
			return true;
		end
	end
	print("found no fuel");
	return false;
end

return TurtleFuel;
