--[[
    Author: Alija Bobija
    Website: http://abobija.com
]]

require "config"

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


local api = nil

local init_api = function()
    if CONFIG.api_enabled and api == nil then
        api = require('api32')
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
