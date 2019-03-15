--[[
    Author: Alija Bobija
    Website: http://abobija.com
]]

require 'config'

local BLUE_LED = 2

local syncer = require('syncer').create({
    interval    = CONFIG.sync_interval,
    host        = CONFIG.dyndns_rec_host,
    domain      = CONFIG.dyndns_rec_domain,
    pass        = CONFIG.dyndns_pass,
    api_enabled = CONFIG.api_enabled
})

gpio.config({ gpio = BLUE_LED, dir = gpio.OUT })
gpio.write(BLUE_LED, 0)

syncer.on_before_sync = function()
    gpio.write(BLUE_LED, 1)
end

syncer.on_after_sync = function()
    gpio.write(BLUE_LED, 0)
end

local function home_endpoint(jreq)
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
end

local function config_endpoint(jreq)
    local res = {}
    if jreq == nil then return res end

    if jreq.sync_interval ~= nil then
        CONFIG.sync_interval = jreq.sync_interval
        syncer.update_interval(CONFIG.sync_interval)
    end
    
    if jreq.dyndns_rec_host ~= nil then
        CONFIG.dyndns_rec_host = jreq.dyndns_rec_host
        syncer.host = CONFIG.dyndns_rec_host
    end

    if jreq.dyndns_rec_domain ~= nil then
        CONFIG.dyndns_rec_domain = jreq.dyndns_rec_domain
        syncer.domain = CONFIG.dyndns_rec_domain
    end

    if jreq.dyndns_pass ~= nil then
        CONFIG.dyndns_pass = jreq.dyndns_pass
        syncer.pass = CONFIG.dyndns_pass
    end
    
    res.success = true
    return res
end

local api = nil

local init_api = function()
    if CONFIG.api_enabled and api == nil then
        api = require('api32')
            .create({
                port = 80
            })
            .on_get('/', home_endpoint)
            .on_post('/config', config_endpoint)
    end
end

wifi.mode(wifi.STATION)

wifi.sta.config({
    ssid = CONFIG.wifi_ssid,
    pwd  = CONFIG.wifi_pwd,
    auto = false
})

wifi.sta.on('connected', syncer.fire_sta_connected)

wifi.sta.on('got_ip', function(e, info)
    if CONFIG.api_enabled then
        init_api()
    end

    syncer.fire_sta_got_ip(e, info)
end)

wifi.sta.on('disconnected', syncer.fire_sta_disconnected)

wifi.start()
wifi.sta.connect()
