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

local syncer_fire_after_sync = function(syncer, _tmr)
    if syncer.on_after_sync ~= nil then
        syncer.on_after_sync(syncer)
    end

    _tmr:start()
end

local syncer_sync = function(syncer, _tmr)
    _tmr:stop()

    if syncer.on_before_sync ~= nil then
        syncer.on_before_sync(syncer)
    end

    print('[DynDnsSyncer] get_public_ip...')
    
    get_public_ip(function(code, public_ip)
        if(code < 0) then
            print('http req failed', code)
            syncer_fire_after_sync(syncer, _tmr)
        else
            print('[DynDnsSyncer] update_dyn_dns_record...')
        
            update_dyn_dns_record({
                host   = syncer.host,
                domain = syncer.domain,
                pass   = syncer.pass,
                ip     = public_ip
            }, function(code, res)
                if(code < 0) then
                    print('http req failed', code)
                    syncer_fire_after_sync(syncer, _tmr)
                else
                    print('[DynDnsSyncer]', res)
                    syncer_fire_after_sync(syncer, _tmr)
                end
            end)
        end
    end)
end

NameCheapDynDnsSyncer = {
    create = function(conf)
        local self = {
            interval       = conf.interval,
            host           = conf.host,
            domain         = conf.domain,
            pass           = conf.pass,
            on_before_sync = conf.on_before_sync,
            on_after_sync  = conf.on_after_sync
        }

        local sync_tmr = tmr.create()

        sync_tmr:register(self.interval * 6e4, tmr.ALARM_AUTO, function()
            syncer_sync(self, sync_tmr)
        end)

        self.fire_sta_connected = function(e, info) 
            print('[STA ', e, '] to ', info.ssid)
        end
        
        self.fire_sta_got_ip = function(e, info)
            print('[STA ', e, '] ', info.ip, ' netmask = ', info.netmask, ' gateway = ', info.gw)

            syncer_sync(self, sync_tmr)
        end
        
        self.fire_sta_disconnected = function(e, info)
            print('[STA ', e, '] reason = ', info.reason)
            sync_tmr:stop()
        end
        
        return self
    end
}