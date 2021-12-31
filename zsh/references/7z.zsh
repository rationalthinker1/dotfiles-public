7z a \
  -t7z -m0=lzma2 -mx=9 -mfb=64 \
  -md=32m -ms=on -mhe=on -p'eat_my_shorts' \
   archive.7z dir1

a                   Add (dir1 to archive.7z)
-t7z                Use a 7z archive
-m0=lzma2           Use lzma2 method
-mx=9               Use the '9' level of compression = Ultra
-mfb=64             Use number of fast bytes for LZMA = 64
-md=32m             Use a dictionary size = 32 megabytes
-ms=on              Solid archive = on
-mhe=on             7z format only : enables or disables archive header encryption
-p{Password}        Add a password
