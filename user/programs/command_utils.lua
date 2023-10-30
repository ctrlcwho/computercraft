CMD = {
    STATES = {
        STARTED = "STARTED",
        DONE = "DONE"
    }
};

COMMAND_FILE_PATH = "/user/data/command.data";
COMMAND_RESULT_FILE_PATH = "/user/data/command_result.data";

local function serializeCommandResult(name, result)
    if type(result) ~= table then return end;
    local file = fs.open(COMMAND_RESULT_FILE_PATH, "w");
    if not file then return error("Command result file couldn't be opened") end;

    result.COMMAND = name;
    serialize(file, result);
    file.close();
end

local function deserializeCommandResult()
    local file = fs.open(COMMAND_RESULT_FILE_PATH, "r");
    if not file then return error("Command result file couldn't be opened") end;

    local data = deserialize(file);
    file.close();
    return data;
end

local function serializeCommand(name, state, parameters)
    local file = fs.open(COMMAND_FILE_PATH, "w");
    if not file then return error("Command file couldn't be opened") end;

    local data = {
        COMMAND = name,
        STATE = state
    };
    for k, v in pairs(parameters) do
        data[k] = v;
    end
    serialize(file, data);
    file.close();
end

local function deserializeCommand()
    local file = fs.open(COMMAND_FILE_PATH, "r");
    if not file then return error("Command file couldn't be opened") end;

    local data = deserialize(file);
    file.close();
    local registeredCommand = turtle.commands[data.COMMAND];
    if not registeredCommand then return error("Command " .. data.COMMAND .. " was not previously registered, cannot deserialize it.") end;

    local parameters = transformTable(data,
            function (key) return key ~= "COMMAND" and key ~= "STATE" end,
            turtle.commands[data.COMMAND].valueTransformer
    );
    return data.COMMAND, data.STATE, parameters;
end

function CMD.resume()
    local command, state, parameters = deserializeCommand();
    if state == CMD.STATES.DONE then return nil end;

    local registeredCommand = turtle.commands[command];
    if not registeredCommand then
        print("Can't resume command " .. command .. " because it's not registered, it should be registered at turtle startup.");
        return nil;
    end

    local result = registeredCommand.fn(parameters);
    CMD.markDone(command);
    serializeCommandResult(command, result);
    return result;
end

function CMD.markDone(name)
    local command, state, parameters = deserializeCommand();
    if command ~= name or state == CMD.STATES.DONE then return end;
    serializeCommand(command, CMD.STATES.DONE, parameters);
end

function CMD.wrapCommand(name, commandFn, modifyParamsCallback)
    return function (parameters)
        modifyParamsCallback = modifyParamsCallback or identity;
        -- first we serialize the command as `STARTED` so that it can be resumed later,
        -- let's hope the turtle doesn't get unloaded before it's fully serialized (foreshadowing)
        parameters = modifyParamsCallback(parameters);
        serializeCommand(name, CMD.STATES.STARTED, parameters);

        local result = commandFn(parameters);
        CMD.markDone(name);
        serializeCommandResult(name, result);
        return result;
    end
end

function CMD.updateOwnState(parameters)
    local command, state, _ = deserializeCommand();
    if state == CMD.STATES.DONE then
        return;
    end
    serializeCommand(command, state, parameters);
end

function CMD.getLastResult()
    return deserializeCommandResult();
end
