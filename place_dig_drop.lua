args = {...};

local placeDirection = args[1] or "front";
local dropDirection = args[2];

function place(direction)
    if direction == "front" then turtle.place()
    elseif direction == "up" then turtle.placeUp()
    elseif direction == "down" then turtle.placeDown();
    end
end

function dig(direction)
    if direction == "front" then turtle.dig()
    elseif direction == "up" then turtle.digUp()
    elseif direction == "down" then turtle.digDown();
    end
end

function drop(direction)
    if direction == "front" then turtle.drop()
    elseif direction == "up" then turtle.dropUp()
    elseif direction == "down" then turtle.dropDown();
    end
end

for i = 1, 16 do
    local item = turtle.getItemDetail(i);
    if item then
        turtle.select(i);
        for j = 1, item.count do
            place(placeDirection);
            dig(placeDirection);
            drop(dropDirection);
        end
    end
end