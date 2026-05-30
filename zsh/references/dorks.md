# 🧠 Google Dorks Cheat Sheet

## 🔍 Core Operators

```
site:example.com                     # Limit results to a specific domain
intitle:"keyword"                    # Page title contains keyword
allintitle:"key1 key2"              # Page title contains ALL keywords
inurl:"keyword"                      # URL contains keyword
allinurl:"key1 key2"               # URL contains ALL keywords
intext:"keyword"                     # Page body contains keyword
filetype:pdf                         # Match specific file type
ext:pdf                              # Same as filetype (alternative syntax)
cache:example.com                    # Google's cached version of a page
related:example.com                  # Sites similar to domain
info:example.com                     # Summary info about a domain
```

## 🔧 Boolean and Modifiers

```
"exact phrase"                       # Exact match (no word reordering)
keyword1 OR keyword2                 # Match either term
keyword1 | keyword2                  # Same as OR
-keyword                             # Exclude term from results
+keyword                             # Force include term
*                                    # Wildcard (fill in the blank)
AROUND(3) keyword1 keyword2          # Words within 3 words of each other
```

## 📁 File Discovery by Site

```
# Replace {site} with your target domain, {ext} with any extension:
site:{site} filetype:{ext}

# Common extensions: pdf, docx, xlsx, pptx, csv, txt, rtf, odt
#                    json, xml, yml, sql, db, log, conf, ini, env
#                    py, js, ts, java, cpp, c, cs, go, rb, php, rs, sh
#                    zip, rar, 7z, tar, gz
```

## 🗂️ Directory Listings

```
site:{site} intitle:"index of"                    # Open directory listings
site:{site} intitle:"index of" "parent directory"  # Classic Apache dir listing
site:{site} intitle:"index of" "last modified"     # Directory with timestamps
site:{site} intitle:"index of" filetype:sql        # SQL files in open directories
```

## 🔑 Sensitive Information Discovery

```
site:{site} inurl:admin              # Admin panels
site:{site} inurl:login              # Login pages
site:{site} intitle:"dashboard"      # Dashboards
site:{site} filetype:env "DB_PASSWORD"    # Exposed .env files with DB creds
site:{site} filetype:log "password"       # Passwords leaked in logs
site:{site} "phpinfo()"                   # Exposed PHP info pages
site:{site} intitle:"index of" ".git"     # Exposed git repositories
site:{site} inurl:wp-content              # WordPress sites
site:{site} inurl:wp-admin               # WordPress admin pages
```

## 🌐 Third-Party File Shares

```
# Replace {keyword} with your search term (e.g., "udemy", "photoshop", "course name")

# --- Cloud Storage ---
"drive.google.com/open?id=" {keyword}              # Google Drive shared files
"drive.google.com/drive/folders" {keyword}         # Google Drive shared folders
"drive.google.com/file/d/" {keyword}               # Google Drive direct file links
"onedrive.live.com/redir?resid=" {keyword}         # OneDrive shared links
"1drv.ms/" {keyword}                               # OneDrive short links
"dropbox.com/s/" {keyword}                         # Dropbox shared links
"dropbox.com/sh/" {keyword}                        # Dropbox shared folder links
"box.com/s/" {keyword}                             # Box.com shared links
"icloud.com/iclouddrive/" {keyword}                # iCloud Drive shared folders
"yadi.sk/" {keyword}                               # Yandex Disk shared links
"disk.yandex.com/d/" {keyword}                     # Yandex Disk (alt URL)
"pcloud.com/fm/" {keyword}                         # pCloud shared links
"sync.com/dl/" {keyword}                           # Sync.com shared downloads

# --- MEGA ---
"mega.nz/folder/" {keyword}                        # MEGA shared folders
"mega.nz/file/" {keyword}                          # MEGA single file links
"mega.co.nz/#F!" {keyword}                         # MEGA legacy folder links

# --- Document Sharing ---
"scribd.com/document/" {keyword}                   # Scribd documents
"issuu.com/" {keyword} filetype:pdf                # Issuu publications
"slideshare.net/" {keyword}                        # SlideShare presentations
"docs.google.com/document" {keyword}               # Google Docs (public)
"docs.google.com/spreadsheets" {keyword}           # Google Sheets (public)
"docs.google.com/presentation" {keyword}           # Google Slides (public)
"notion.so/" {keyword}                             # Notion public pages
"confluence" inurl:viewpage {keyword}              # Confluence wiki pages

# --- Premium File Hosts ---
"https://uploadgig.com/file/download" {keyword}    # UploadGig
"https://rapidgator.net/file/" {keyword}           # Rapidgator
"http://nitroflare.com/view/" {keyword}            # NitroFlare
"katfile.com/download/" {keyword}                  # KatFile
"filefox.cc/" {keyword}                            # FileFox
"ddownload.com/" {keyword}                         # DDownload
"1fichier.com/" {keyword}                          # 1Fichier
"alfafile.net/file/" {keyword}                     # AlfaFile
"turbobit.net/" {keyword}                          # TurboBit
"hitfile.net/download/" {keyword}                  # HitFile
"wdupload.com/file/" {keyword}                     # WDUpload
"filestore.me/" {keyword}                          # FileStore

# --- Free File Hosts ---
"mediafire.com/file/" {keyword}                    # MediaFire
"mediafire.com/folder/" {keyword}                  # MediaFire folders
"zippyshare.com/v/" {keyword}                      # ZippyShare (defunct, archive)
"4shared.com/file/" {keyword}                      # 4Shared
"sendspace.com/file/" {keyword}                    # SendSpace
"transfer.sh/" {keyword}                           # Transfer.sh CLI uploads
"wetransfer.com/downloads/" {keyword}              # WeTransfer
"anonfiles.com/" {keyword}                         # AnonFiles
"gofile.io/d/" {keyword}                           # GoFile
"pixeldrain.com/u/" {keyword}                      # Pixeldrain
"filebin.net/" {keyword}                           # FileBin
"bayfiles.com/" {keyword}                          # BayFiles

# --- Code / Text Snippets ---
"gist.github.com/" {keyword}                       # GitHub Gists
"pastebin.com/" {keyword}                          # Pastebin
"paste.ee/" {keyword}                              # Paste.ee
"ghostbin.co/" {keyword}                           # Ghostbin
"hastebin.com/" {keyword}                          # Hastebin

# --- Torrent / P2P Indexes ---
"magnet:?xt=urn:btih:" {keyword}                   # Magnet links indexed by Google
site:btdig.com {keyword}                           # BTDig torrent search
site:thepiratebay.org {keyword}                    # The Pirate Bay
site:1337x.to {keyword}                            # 1337x
site:rutracker.org {keyword}                       # Rutracker (Russian tracker)
```

## 🧰 Advanced Combos

```
site:{site} -inurl:www                        # Subdomains only (exclude www)
site:*.{site} -site:www.{site}                # Enumerate subdomains
site:{site} inurl:api                         # API endpoints
site:{site} filetype:pdf after:2024-01-01     # Recent PDFs only
site:{site} "error" | "warning" | "exception" # Error pages
-site:pinterest.* -site:facebook.com {query}  # Exclude noisy social sites
```

## ⚠️ Notes

```
# Combine operators for precision: site:example.com filetype:pdf "annual report"
# Google may rate-limit or CAPTCHA automated dorking
# Use responsibly — only on domains you have authorization to test
# Results depend on what Google has indexed — not a complete view
```

