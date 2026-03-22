# 🧠 curl Cheat Sheet

## 🔍 Basic Usage

```bash
curl https://example.com                        # GET request, print to stdout
curl -o file.html https://example.com           # Save output to file
curl -O https://example.com/file.zip            # Save with remote filename
curl -L https://example.com                     # Follow redirects (3xx)
curl -s https://example.com                     # Silent mode (no progress bar)
curl -sS https://example.com                    # Silent but show errors
curl -v https://example.com                     # Verbose (show headers, TLS handshake)
```

## 📤 HTTP Methods

```bash
curl -X POST https://api.example.com/data       # POST request (empty body)
curl -X PUT https://api.example.com/data        # PUT request
curl -X PATCH https://api.example.com/data      # PATCH request
curl -X DELETE https://api.example.com/data/1   # DELETE request
```

## 📦 Sending Data

```bash
curl -d "key=value&foo=bar" https://api.example.com          # POST form data (application/x-www-form-urlencoded)
curl -d @data.json https://api.example.com                   # POST data from file
curl -F "file=@photo.jpg" https://api.example.com/upload     # Multipart file upload
curl -F "file=@photo.jpg" -F "name=avatar" https://api.example.com  # File + form field
curl --data-raw '{"key":"value"}' https://api.example.com    # POST raw string (no @ interpretation)
curl --data-urlencode "q=hello world" https://api.example.com # Auto URL-encode data
```

## 🔑 Headers and Auth

```bash
curl -H "Content-Type: application/json" https://api.example.com        # Set header
curl -H "Authorization: Bearer TOKEN" https://api.example.com           # Bearer token
curl -H "Content-Type: application/json" -d '{"key":"val"}' URL         # JSON POST
curl -u user:pass https://api.example.com                               # Basic auth
curl -u user https://api.example.com                                    # Basic auth (prompts for password)
curl -b "session=abc123" https://example.com                            # Send cookies
curl -c cookies.txt https://example.com                                 # Save cookies to file
curl -b cookies.txt https://example.com                                 # Load cookies from file
```

## 📋 Response Control

```bash
curl -I https://example.com                     # HEAD request (headers only)
curl -i https://example.com                     # Include response headers in output
curl -w "%{http_code}" -o /dev/null -s URL      # Print only HTTP status code
curl -w "%{time_total}\n" -o /dev/null -s URL   # Print request time
curl -w "\n%{http_code} %{size_download} %{time_total}s\n" -sS URL  # Status + size + time
curl -D headers.txt https://example.com         # Dump response headers to file
```

## 📁 Downloads

```bash
curl -O https://example.com/file.zip                         # Save with original filename
curl -o custom.zip https://example.com/file.zip              # Save with custom filename
curl -O -C - https://example.com/large.zip                   # Resume interrupted download
curl -O --limit-rate 1M https://example.com/large.zip        # Limit download speed to 1MB/s
curl -O -J -L https://example.com/download                   # Follow redirects + use server filename
curl -Z -O https://a.com/1.zip -O https://b.com/2.zip       # Parallel downloads
```

## 🔒 TLS and Certificates

```bash
curl -k https://self-signed.example.com         # Skip TLS verification (insecure)
curl --cacert ca.pem https://example.com        # Use custom CA certificate
curl --cert client.pem https://example.com      # Client certificate auth
curl --cert client.pem --key key.pem URL        # Client cert + private key
```

## 🌐 Proxy and Network

```bash
curl -x http://proxy:8080 https://example.com   # Use HTTP proxy
curl -x socks5://proxy:1080 https://example.com # Use SOCKS5 proxy
curl --connect-timeout 5 https://example.com    # Connection timeout (seconds)
curl -m 30 https://example.com                  # Max total time (seconds)
curl --retry 3 https://example.com              # Retry on transient errors
curl --retry 3 --retry-delay 2 URL              # Retry with delay between attempts
curl -4 https://example.com                     # Force IPv4
curl -6 https://example.com                     # Force IPv6
curl --interface eth0 https://example.com       # Bind to specific interface
curl --resolve example.com:443:1.2.3.4 https://example.com  # Override DNS resolution
```

## 🧰 Advanced

```bash
curl -s URL | jq "."                                     # Pipe JSON response to jq
curl -sw "%{http_code}" -o /dev/null URL                 # Quick health check (status code only)
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"test"}' https://api.example.com/items     # Full JSON POST
curl --compressed https://example.com                    # Request gzip/deflate compression
curl -A "Mozilla/5.0" https://example.com                # Set User-Agent string
curl -e "https://google.com" https://example.com         # Set Referer header
curl -K config.txt                                       # Read options from file
```

## 🔗 Common Combos

```bash
curl -sS https://api.example.com/data | jq "."                        # Fetch and pretty-print JSON
curl -sw "%{http_code} %{time_total}s\n" -o /dev/null URL             # Quick endpoint check
curl -u user:pass -X POST -H "Content-Type: application/json" \
  -d @payload.json https://api.example.com                             # Authenticated JSON POST
curl -sL https://raw.githubusercontent.com/user/repo/main/install.sh | bash  # Pipe install script
cat urls.txt | xargs -P 8 -I {} curl -sO {}                           # Parallel download from list
for i in {1..5}; do curl -sw "$i: %{http_code} %{time_total}s\n" -o /dev/null URL; done  # Simple load test
```

## ⚠️ Gotchas

```bash
# -d implies POST — no need for -X POST when using -d
# -F implies multipart/form-data — don't mix with -d
# Redirects: use -L or you'll get empty/3xx responses
# Shell quoting: use single quotes around JSON to avoid $variable expansion
# -o /dev/null discards body — pair with -w for status checks
# macOS curl may differ from GNU curl — check: curl --version
```

