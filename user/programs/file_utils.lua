function deserializationError()
    return error("deserialization error");
end

function clearFile(file)
    file.write("");
end

function serializePath(path, data)
    local file = fs.open(path, "w");
    serialize(file, data);
end

function serialize(file, data)
    assert(file);
    assert(type(data) == "table");

    local stringRep = "";
    for k, v in pairs(data) do
        stringRep = stringRep .. tostring(k) .. "=" .. tostring(v) .. "\n";
    end
    file.write(stringRep);
end

local logfile = fs.open("/user/data/log", "a");
function log(msg)
    logfile.write(msg .. "\n");
    logfile.flush();
end

function logFlush()
    logfile.close();
    logfile = fs.open("/user/data/log", "a");
end

function deserializePath(path, valueTransformer)
    local file = fs.open(path, "r");
    local data = deserialize(file, valueTransformer);
    file.close();
    return data;
end

function deserialize(file, valueTransformer)
    assert(file);
    valueTransformer = valueTransformer or function(_, v) return v end;
    local data = {};

    while true do
        local line = file.readLine();
        if not line then break end;

        local i, _, key, value = string.find(line, "(.+)=(.+)");
        if i then
            data[key] = valueTransformer(key, value);
        end
    end
    return data;
end