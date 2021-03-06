# Esp32 DynDNS Syncer
If you got stuck in situation in which you want to make a "A" DNS record for your domain that will point to the IP address of your home, but your home IP address is not static, this project is solution for your problem. Device realized in this project represents the client for auto-updating the DNS (A + DynDNS) record on Namecheap.com domain provider.

The device checks, at the given time intervals, whether a public IP address (of your home) has changed. When IP address change is detected, DNS (A + DynDNS) record will be automatically updated by calling [Namecheap API endpoint](https://www.namecheap.com/support/knowledgebase/article.aspx/29/11/how-do-i-use-a-browser-to-dynamically-update-the-hosts-ip).

## Endpoints
Application uses [Api32](https://github.com/abobija/api32) library for serving, so all requests and responses need to be presented in `JSON` format.

- `GET /`

  **Returns**: 
  
  System informations along with configuration
  
  | Param | Description | Type | Nullable |
  | --- | --- | --- | --- |
  | `last_sync_time` | Time of last DNS synchronization (relative to `uptime`) | `long` | Yes |
  | `id` | Chip (device) ID | `string` | No |
  | `domain` | DNS domain | `string` | No |
  | `local_ip` | Local IP address | `string` | No |
  | `host` | DNS host | `string` | No |
  | `name` | Name of device | `string` | No |
  | `heap` | Available heap memory on device | `long` | No |
  | `uptime` | Time passed since device is live (microseconds) | `long` | No |
  | `sync_interval` | Interval of DNS synchronization (minutes) | `integer` | No |
  | `public_ip` | Devices public IP address | `string` | Yes |
  | `last_global_ip_check_time` | Time of last global IP check (relative to `uptime`) | `long` | Yes |

- `POST /config`

  Configuration update
  
  **Accept**:
  
  | Param | Description | Type |
  | --- | --- | --- |
  | `sync_interval` | Interval of DNS synchronization (minutes) | `integer` |
  | `dyndns_rec_host` | DNS host | `string` |
  | `dyndns_rec_domain` | DNS domain | `string` |
  | `dyndns_pass` | Namecheap DynDNS password | `string` |
  
  **Returns**:
  
  | Param | Description | Type | Nullable |
  | --- | --- | --- | --- |
  | `success` | Success indicator | `boolean` | No |
  
  **Example**:
  
  ```
  {
    "sync_interval": 10,
    "dyndns_rec_host": "device",
    "dyndns_rec_domain": "abobija.com",
    "dyndns_pass": "my_secret_namecheap_dyndns_key"
  }
  ```
  
  ```
  {
    "success": true
  }
  ```

## Dependencies
Project depends on the following NodeMCU modules:
  - `gpio`
  - `file`
  - `node`
  - `wifi`
  - `http`
  - `tmr`
  - Modules required by [`Api32`](https://github.com/abobija/api32#dependencies) library
