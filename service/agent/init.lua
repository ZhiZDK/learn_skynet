local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg, source)
        if ret_msg then
            skynet.send(source, "lua", "send", s.id, ret_msg)
        else
            skynet.error("s.resp.client fail", cmd)
        end
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
    -- 保存角色数据
    skynet.sleep(200)
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

s.start(...)
