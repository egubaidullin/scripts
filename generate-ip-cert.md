# self-signed SSL certificate generation script
## script: generate-ip-cert.sh
This script allows you to create a self-signed SSL certificate for an IP address. This can be useful if you want to use HTTPS for a local or internal server.

## How to use

Replace 127.0.0.1 with the desired IP:

```bash
curl -sS https://raw.githubusercontent.com/egubaidullin/scripts/main/generate-ip-cert.sh | bash -s 127.0.0.1
```
This will create two files: cert.pem and key.pem.

## Requirements

This script requires `curl` and `openssl` to be installed on your system.


