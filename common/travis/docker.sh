#!/bin/sh
#
# docker.sh

[ "$PKGINSTLINT" ] && exit 0

/bin/echo -e "\x1b[32mPulling docker image for $BOOTSTRAP from $TAG...\x1b[0m"
docker pull plan10/masterdir-$BOOTSTRAP:$TAG
docker run -d \
	   --name plan10 \
	   -v "$(pwd)":/hostrepo \
	   -v /tmp:/tmp \
	   -e PKGINSTLINT="$PKGINSTLINT" \
	   -e PATH="$PATH" \
	   plan10/masterdir-$BOOTSTRAP:$TAG \
	   /bin/sh -c 'sleep inf'
