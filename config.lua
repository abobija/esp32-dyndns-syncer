CONFIG = {
    wifi_ssid         = 'MyWifi',
    wifi_pwd          = 'MyWifiPassword',

    sync_interval     = 10, -- minutes
    
    dyndns_rec_host   = 'router',
    dyndns_rec_domain = 'my-domain.com',
    dyndns_pass       = '********************************', -- generated in 'DYNAMIC DNS' section of 'namecheap.com' dashboard

    api_enabled       = true,
    api_auth          = { user = 'admin', pwd = '********' } -- Set to nil for no auth
}
