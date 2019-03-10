Api = {}

Api.create = function(conf) 
    local self = {
        port   = conf.port,
        syncer = conf.syncer
    }
    
    local srv = net.createServer(net.TCP, 30)

    local receiver = function(sck, data)
        local res = {}

        res[#res + 1] = "HTTP/1.1 200 OK\r\n"
        res[#res + 1] = "Content-Type: text/plain; charset=UTF-8\r\n"
        res[#res + 1] = "\r\n"
        
        res[#res + 1] = "~ ESP32 DynDNS Syncer\r\n\r\n"

        local uptime_l, uptime_h
        uptime_l, uptime_h = node.uptime()
        
        res[#res + 1] = '- Public IP: ' .. self.syncer.public_ip .. "\r\n"
        res[#res + 1] = '- [Host].[Domain]: ' .. self.syncer.host .. '.' .. self.syncer.domain .. "\r\n"
        res[#res + 1] = '- Sync Interval: ' .. self.syncer.interval .. ' [min]' .. "\r\n"
        res[#res + 1] = '- Uptime: ' .. uptime_l .. ' + (' .. uptime_h .. ' * 2^31) [us]' .. "\r\n"

        local send = function(_sck)
            if #res > 0 then
                _sck:send(table.remove(res, 1))
            else
                _sck:close()
                response = nil
            end
        end
        
        sck:on("sent", send)
        send(sck)
    end

    if srv then
        srv:listen(self.port, function(conn)
            conn:on('receive', receiver)
        end)
    end

    return self
end