assert(turtle.pos, "Turtle not initialized!");

args = {...};

-- tagged or coordinate mode
local parameters = tonumber(args[1]) == nil and {
    tag = args[1],
    faceDirection = args[2]
} or {
    target = vector.new(tonumber(args[1]), tonumber(args[2]), tonumber(args[3])),
    faceDirection = args[4]
}

turtle.commands.goTo.fn(parameters);