#!/bin/bash
if [ -n "$MAKELOVE_VERSION" ]; then
	echo $MAKELOVE_VERSION
else
	version=git-$(git rev-parse --short HEAD)-$(git rev-parse --abbrev-ref HEAD)
	! git diff-index --quiet HEAD && version="$version-changed"
	echo $version
fi
