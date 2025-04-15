local skynet = require "skynet"
local s = require "service"

s.client = {}

s.resp.client = function(source, fd, cmd, msg)
    skynet.error("login init client recv ", source, ", fd:", fd, ", cmd:", cmd, ", msg:", msg)
    if s.client[cmd] then
        local ret_msg = s.client[cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else
        skynet.error("[login] s.resp.client fail", cmd)
    end
end

s.client.login = function(fd, msg, source)
    local playerid = tonumber(msg[2])
    local pw = tonumber(msg[3])
    local gate = source
    local node = skynet.getenv("node")
    if pw ~= 123 then
        return {"login", 1, "密码错误"}
    end

    skynet.error("[login] pw succ")

    -- 发送给agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    skynet.error("[login] send to agentmgr")
    if not isok then
        return {"login", 1, "请求mgr失败"}
    end

    skynet.error("[login] login agentmgr sucee")

    -- 回应gate
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        return {"login", 1, "gate注册上失败"}
    end

    skynet.error("login succ" .. playerid)
    return {"login", 0, "登录成功"}
end

s.start(...)
