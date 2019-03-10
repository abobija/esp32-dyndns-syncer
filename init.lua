require "config"
require "syncer"

local BLUE_LED = 2

local syncer = NameCheapDynDnsSyncer.create({
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

wifi.mode(wifi.STATION)

wifi.sta.config({
    ssid = CONFIG.wifi_ssid,
    pwd  = CONFIG.wifi_pwd,
    auto = false
})

wifi.sta.on('connected',    syncer.fire_sta_connected)
wifi.sta.on('got_ip',       syncer.fire_sta_got_ip)
wifi.sta.on('disconnected', syncer.fire_sta_disconnected)

wifi.start()
wifi.sta.connect()
