Api = {}

local function str_split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local result = {}
    for str in inputstr:gmatch("([^"..sep.."]+)") do table.insert(result, str) end
    
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
            res[#res + 1] = "Content-Type: application/json; charset=UTF-8\r\n"
            res[#res + 1] = "\r\n"

            res[#res + 1] = '{' .. "\r\n"
                    .. '"id": "' .. node.chipid() .. '"' .. ",\r\n"
                    .. '"name": "ESP32 DynDNS Syncer"' .. ",\r\n"
                    .. '"uptime": ' .. node.uptime() .. ",\r\n"
                    .. '"heap": ' .. node.heap() .. ",\r\n"
                    .. '"local_ip": "' .. self.syncer.local_ip .. '"' .. ",\r\n"
            
            res[#res + 1] = '"public_ip": '

            if self.syncer.public_ip == nil then
                res[#res + 1] = 'null'
            else
                res[#res + 1] = '"' .. self.syncer.public_ip .. '"'
            end
            
            res[#res + 1] = ",\r\n"
                    .. '"host": "' .. self.syncer.host .. '"' .. ",\r\n"
                    .. '"domain": "' .. self.syncer.domain .. '"' .. ",\r\n"
                    .. '"sync_interval": ' .. self.syncer.interval .. "\r\n"
                .. '}'
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
