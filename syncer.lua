local NameCheapDynDnsSyncer = {
    DNS_RECORD_UPDATED  = 1,
    PUBLIC_IP_NO_CHANGE = 2,
    PUBLIC_IP_SERVICE_HTTP_REQ_ERROR = 3,
    DNR_RECORD_UPDATE_SERVICE_HTTP_REQ_ERROR = 4
}

local get_public_ip = function(callback)
    http.get('http://api.ipify.org', callback)
end

local update_dyn_dns_record = function(options, callback)
    http.get('http://dynamicdns.park-your-domain.com/update?'
        .. 'host='      .. options.host
        .. '&domain='   .. options.domain
        .. '&password=' .. options.pass
        .. '&ip='       .. options.ip, callback)
end

local syncer_fire_after_sync = function(syncer, result, _tmr)
    print('[DynDnsSyncer] result.code =', result.code)

    if syncer.on_after_sync ~= nil then
        syncer.on_after_sync(syncer, result)
    end

    _tmr:start()
end

local syncer_sync = function(syncer, _tmr)
    _tmr:stop()

    if syncer.on_before_sync ~= nil then
        syncer.on_before_sync(syncer)
    end

    print('[DynDnsSyncer] get_public_ip()...')
    
    get_public_ip(function(code, public_ip)
        if code ~= 200 then
            print('http req failed', code)
            
            syncer_fire_after_sync(syncer, {
                code = NameCheapDynDnsSyncer.PUBLIC_IP_SERVICE_HTTP_REQ_ERROR,
                http_code = code
            }, _tmr)
        else
            print('[DynDnsSyncer] public_ip =', public_ip)

            syncer.last_global_ip_check_time = node.uptime()
            
            if syncer.public_ip ~= nil and syncer.public_ip == public_ip then
                print('[DynDnsSyncer] public ip has not changed')
                
                syncer_fire_after_sync(syncer, {
                    code = NameCheapDynDnsSyncer.PUBLIC_IP_NO_CHANGE
                }, _tmr)
                
                return
            end

            syncer.public_ip = public_ip
            
            print('[DynDnsSyncer] update_dyn_dns_record()...')
        
            update_dyn_dns_record({
                host   = syncer.host,
                domain = syncer.domain,
                pass   = syncer.pass,
                ip     = syncer.public_ip
            }, function(code, res)
                if code ~= 200 then
                    print('http req failed', code)
                    
                    syncer_fire_after_sync(syncer, {
                        code = NameCheapDynDnsSyncer.DNR_RECORD_UPDATE_SERVICE_HTTP_REQ_ERROR,
                        http_code = code
                    }, _tmr)
                else
                    print('[DynDnsSyncer]', res)

                    syncer.last_sync_time = node.uptime()
                    
                    syncer_fire_after_sync(syncer, {
                        code = NameCheapDynDnsSyncer.DNS_RECORD_UPDATED
                    }, _tmr)
                end
            end)
        end
    end)
end

local init_api = function(syncer, _tmr)
    if syncer.api_enabled == true and syncer.api == nil then
        syncer.api = require('api32')
            .create({
                port = 80
            })
            .on_get('/', function(jreq)
                local response = {
                    id                        = node.chipid(),
                    name                      = "ESP32 DynDNS Syncer",
                    uptime                    = node.uptime(),
                    heap                      = node.heap(),
                    local_ip                  = syncer.local_ip,
                    public_ip                 = syncer.public_ip,
                    host                      = syncer.host,
                    domain                    = syncer.domain,
                    sync_interval             = syncer.interval,
                    last_sync_time            = syncer.last_sync_time,
                    last_global_ip_check_time = syncer.last_global_ip_check_time
                }
            
                return response
            end)
    end
end

NameCheapDynDnsSyncer.create = function(conf)
    local self = {
        interval                  = conf.interval,
        host                      = conf.host,
        domain                    = conf.domain,
        pass                      = conf.pass,
        api_enabled               = conf.api_enabled,
        api                       = nil,
        on_before_sync            = conf.on_before_sync,
        on_after_sync             = conf.on_after_sync,
        public_ip                 = nil,
        local_ip                  = nil,
        last_sync_time            = nil,
        last_global_ip_check_time = nil
    }

    local sync_tmr = tmr.create()

    sync_tmr:register(self.interval * 6e4, tmr.ALARM_AUTO, function()
        syncer_sync(self, sync_tmr)
    end)

    self.fire_sta_connected = function(e, info) 
        print('[DynDnsSyncer] STA:', e, 'to', info.ssid)
    end
    
    self.fire_sta_got_ip = function(e, info)
        print('[DynDnsSyncer] STA:', e, info.ip, ' netmask = ', info.netmask, ' gateway = ', info.gw)

        self.local_ip = info.ip

        if self.api_enabled == true then
            init_api(self, sync_tmr)
        end
        
        syncer_sync(self, sync_tmr)
    end
    
    self.fire_sta_disconnected = function(e, info)
        print('[DynDnsSyncer] STA:', e, 'reason =', info.reason)
        sync_tmr:stop()
    end
    
    return self
end

return NameCheapDynDnsSyncer
