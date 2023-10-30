dofile("/user/programs/turtle_api.lua");

args = {...};

local parameters = {
    name = assert(args[1], "Must provide item name"),
    count = args[2] and tonumber(args[2]),
    direction = args[3]
};

turtle.commands.take.fn(parameters);