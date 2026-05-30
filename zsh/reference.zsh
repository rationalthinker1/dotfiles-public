#!/usr/bin/env bash

# Shred a file securely rewritten 5 times (-n5)
shred -zvu -n5 "${file}"

# Shred a directory securely
wipe -rfi "${folder}"/*

# Creates a 7z securely with password and maximum compression (-mx[1..9])
7z a -t7z -mhe -mx9 -p "${file}".7z "${folder}"

# Searches for text found in apt sources files
grep -R --include="*.list" "${name}" /etc/apt

# Show ports in use
sudo lsof -i -P -n | grep LISTEN

# Show router IP address
route -n

# Rsync for synchronization
rsync \
	--verbose \
	--recursive `# recursively get files/directories` \
	--archive `# preserves permission,owner,time` \
	--acls `# preserves acl` \
	--executability `# preserve executability` \
	--partial `# save partial file. do not rewrite if transfer occurs again` \
	--progress `# show progress during transfer` \
	--compress `# compress during transfer` \
	--ignore-existing `# ignore existing files` \ 
	--human-readable `# human-readable format` \
	--xattrs `# preserves extended attributes` \
	--copy-links `# copy symbolic links to actual files` \
	--rsh="ssh -p 222" `# which port to use and ssh`
	source
	destination

# Wget
wget \
	--verbose \
	--show-progress \
	--mirror `# This option turns on recursion and time-stamping, sets infinite recursion depth and keeps FTP directory listings.` \
	--no-clobber `# ignore already downloaded files` \
	--continue `# continue downloading partially downloaded files` \
	--no-parent `# do not follow links outside the directory` \
	--convert-links `# convert links so that they work locally, off-line` \
	--page-requisites `# get all the elements that compose the page images, CSS and so on` \
	--adjust-extension `# Save files with .html on the end.` \
	--domains website.org `# do not follow links outside website.org` \
	website.org/whatever/path `# The URL to download`
