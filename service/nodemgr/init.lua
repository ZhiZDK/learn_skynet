local skynet = require "skynet"
local s = require "service"

s.resp.newservice = function(source, name, ...)
    skynet.error("[nodemgr] source = ", source, ", name = ", name)
    local srv = skynet.newservice(name, ...)
    return srv
end

s.start(...)
