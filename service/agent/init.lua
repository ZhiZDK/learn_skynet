local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

require "scene"

s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg, source)
        if ret_msg then
            skynet.send(source, "lua", "send", s.id, ret_msg)
        end
    else
        skynet.error("[agent] s.resp.client fail", cmd)
    end
end

s.init = function()
    -- 加载角色数据
    skynet.sleep(200)
    s.data = {
        coin = 100,
        hp = 200
    }
end

s.resp.kick = function(source)
    s.leave_scene()
    -- 保存角色数据
    skynet.error("kick success, source=", source)
end

s.resp.exit = function(source)
    skynet.error("exit success, source=", source)
    skynet.exit()
end

s.client.work = function(msg)
    s.data.coin = s.data.coin + 1
    return {"work", s.data.coin}
end

s.resp.send = function(source, msg)
    skynet.send(s.gate, "lua", "send", s.id, msg)
end

s.start(...)
