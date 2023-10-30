dofile("/user/programs/turtle_api.lua");

args = {...};

local tagName = assert(args[1], "First argument should be the tag name");
local direction = args[2];
local positionX = args[3] and tonumber(args[3]);
local positionY = args[4] and tonumber(args[4]);
local positionZ = args[5] and tonumber(args[5]);

local position = positionX ~= nil and vector.new(positionX, positionY, positionZ);

turtle.tagLocation(tagName, direction, position);