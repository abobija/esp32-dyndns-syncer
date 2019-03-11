Api = {}

local function str_split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    
    local result = {}
    
    for str in inputstr:gmatch("([^"..sep.."]+)") do
        table.insert(result, str)
    end
    
    return result
end

Api.parse_http_request = function(request)
    local first_rn = request:find("\r\n")

    if first_rn ~= nil then
        local parts = str_split(request:sub(1, first_rn))
    
        if #parts == 3 then
            return {
                method = parts[1],
                path   = parts[2],
                std    = parts[3]
            }
        end
    end

    return nil
end

Api.create = function(conf) 
    local self = {
        port   = conf.port,
        syncer = conf.syncer
    }
    
    local srv = net.createServer(net.TCP, 30)

    local receiver = function(sck, data)
        local res = {}
        
        local send = function(_sck)
            if #res > 0 then
                _sck:send(table.remove(res, 1))
            else
                _sck:close()
                response = nil
            end
        end
        
        local req = Api.parse_http_request(data)
        data = nil

        res[1] = 'HTTP/1.1 '
        
        if req == nil then
            res[1] = res[1] .. "400 Bad Request\r\n\r\n"
        else
            print('[DynDnsSyncer:API]', 'method:' .. req.method .. ', path:' .. req.path .. ', std:' .. req.std)
            
            res[1] = res[1] .. "200 OK\r\n"
            
            res[#res + 1] = "Content-Type: text/plain; charset=UTF-8\r\n"
            res[#res + 1] = "\r\n"
            
            res[#res + 1] = "ESP32 DynDNS Syncer\r\n\r\n"
    
            local uptime_us = node.uptime()
            
            res[#res + 1] = 'Public IP       : ' .. self.syncer.public_ip .. "\r\n"
            res[#res + 1] = '<Host>.<Domain> : <' .. self.syncer.host .. '>.<' .. self.syncer.domain .. ">\r\n"
            res[#res + 1] = 'Sync Interval   : ' .. self.syncer.interval .. ' [min]' .. "\r\n"
            res[#res + 1] = 'Uptime          : ' .. (uptime_us / 1e6) .. ' [sec]' .. "\r\n"
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
