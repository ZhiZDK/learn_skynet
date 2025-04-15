local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"

conns = {} -- [fd] = conn
players = {} -- [playerid] = gateplayer

-- 连接类
function conn()
    local m = {
        fd = nil,
        playerid = nil
    }
    return m
end

-- 玩家类
function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil
    }
    return m
end

local str_unpack = function(msgstr)
    local msg = {}

    while true do
        local arg, rest = string.match(msgstr, "(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msgstr)
            break
        end
    end
    return msg[1], msg
end

local str_pack = function(cmd, msg)
    return table.concat(msg, ",") .. "\r\n"
end

local process_msg = function(fd, msgstr)
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv" .. fd .. "[" .. cmd .. "] {" .. table.concat(msg, ",") .. "}")
    local conn = conns[fd]
    local playerid = conn.playerid

    if not playerid then -- 未登录
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login" .. loginid
        skynet.error("begin login:", login, ", fd:", fd, ", cmd:", cmd, ", msg:", msg)
        skynet.send(login, "lua", "client", fd, cmd, msg)
    else -- 已登录
        local gplayer = players[playerid]
        local agent = gplayer.agent
        skynet.send(agent, "lua", "client", cmd, msg)
    end
end

local process_buff = function(fd, readbuff)
    while true do
        local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)")
        if msgstr then
            readbuff = rest
            process_msg(fd, msgstr)
        else
            return readbuff
        end
    end
end

-- 每一条连接接受数据处理
-- 协议格式 cmd,arg1,arg2, ...#
local recv_loop = function(fd)
    socket.start(fd)
    skynet.error("socket connected" .. fd)
    local readbuff = ""
    while true do
        local recvstr = socket.read(fd)
        if recvstr then
            readbuff = readbuff .. recvstr
            readbuff = process_buff(fd, readbuff)
        else
            skynet.error("socket cloes" .. fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end

-- 有新连接时
local connect = function(fd, addr)
    print("connect from " .. addr .. " " .. fd)
    local c = conn()
    c.fd = fd
    conns[fd] = c
    skynet.fork(recv_loop, fd)
end

function s.init()
    skynet.error("[start]" .. s.name .. " " .. s.id)

    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port

    local listenfd = socket.listen("0.0.0.0", port)
    skynet.error("Listen socket : ", "0.0.0.0", port)
    socket.start(listenfd, connect)
end

s.resp.send_by_fd = function(source, fd, msg)
    if not conns[fd] then
        skynet.error("resp.send_by_fd no suce fd")
        return
    end

    local buff = str_pack(msg[1], msg)
    skynet.error("send" .. fd .. " [" .. msg[1] .. "] {" .. table.concat(msg, ",") .. "}")
    socket.write(fd, buff)
end

s.resp.send = function(source, playerid, msg)
    local gplayer = players[playerid]
    if gplayer == nil then
        skynet.error("resp.send no suce player, playerid=", playerid)
        return
    end
    local c = gplayer.conn
    if c == nil then
        return
    end

    s.resp.send_by_fd(nil, c.fd, msg)
end

s.resp.sure_agent = function(source, fd, playerid, agent)
    skynet.error("[gateway] sure_agent, recv, playerid=", playerid)
    local conn = conns[fd]
    if not conn then
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登录即下线")
        return false
    end

    conn.playerid = playerid

    local gplayer = gateplayer()
    gplayer.playerid = playerid
    gplayer.agent = agent
    gplayer.conn = conn
    players[playerid] = gplayer

    return true
end

local disconnect = function(fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    -- 还没完成登录
    if not playerid then
        return
    else
        players[playerid] = nil
        local reason = "断线"
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
    end
end

s.resp.kick = function(source, playerid)
    local gplayer = players[playerid]
    if not gplayer then
        return
    end

    local c = gplayer.conn
    players[playerid] = nil

    if not c then
        return
    end

    conns[c.fd] = nil
    disconnect(c.fd)
end

s.start(...)
