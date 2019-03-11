Api = {}

local function str_split(inputstr, sep)
    if sep == nil then sep = "%s" end
    local result = {}
    for str in inputstr:gmatch("([^"..sep.."]+)") do table.insert(result, str) end
    
    return result
end

Api.json_stringify = function(table)
    local result = '{' .. "\n"

    for k, v in pairs(table) do
        local _type = type(v)
        local quotable = _type ~= 'number' and _type ~= 'boolean'
        
        result = result .. '  ' .. '"' .. k .. '": '

        if quotable then 
            result = result .. '"' .. v .. '"'
        else
            result = result .. v
        end
        
        if next(table, k) ~= nil then
            result = result .. ','
        end
        
        result = result .. '\n'
    end

    return result .. '}'
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
        port = conf.port
    }

    local endpoints = {}

    self.add_endpoint = function(path, handler)
        table.insert(endpoints, {
            path    = path,
            handler = handler
        })
        return self
    end

    local get_endpoint_by_path = function(path)
        for _, ep in pairs(endpoints) do
            if ep.path == path then return ep end
        end

        return nil
    end
    
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

        local response_status = '200 OK'
        
        res[1] = 'HTTP/1.1 '
        res[#res + 1] = "Content-Type: application/json; charset=UTF-8\r\n"
        res[#res + 1] = "\r\n"
        
        if req == nil then
            response_status = '400 Bad Request'
        else
            print('[DynDnsSyncer:API]', 'method:' .. req.method .. ', path:' .. req.path .. ', std:' .. req.std)
            
            local ep = get_endpoint_by_path(req.path)
            local res_json_tbl = {}
            
            if ep == nil then
                response_status = '404 Not Found'
            else
                res_json_tbl = ep.handler(self, req)
                res[#res + 1] = Api.json_stringify(res_json_tbl)
            end
        end

        res[1] = res[1] .. response_status .. "\r\n"
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

return Api