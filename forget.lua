dofile("/user/programs/turtle_api.lua");

args = {...};

local tagName = assert(args[1], "First argument should be the tag name");

turtle.removeTag(tagName);