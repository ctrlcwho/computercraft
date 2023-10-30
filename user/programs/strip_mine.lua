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

movingAwayFromBase = true;
distanceLeftToTravel = tunnelLength;
cyclesLeft = cycles;
tunnelMethod = nil;
mineVeinMethod = nil;

mineVeinMethod = function () return TurtleMine.mineVein(
		function ()
			if TurtleFuel.needsRefueling(80) then
				TurtleFuel.refuel(2);
			end
		end,
		TurtleMine.isOre
) end;

returnToBaseMethod = function ()
	local movesCount = (cycles - cyclesLeft) * 3;
	turtle.turnRight();
	for i = 1, movesCount do
		turtle.dig();
		turtle.forward();
	end
	turtle.turnRight();
end

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