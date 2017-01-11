#!/usr/bin/env bash

set -eu
set -o pipefail

pushd buildpack-master
  export BUNDLE_GEMFILE=cf.Gemfile
  bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
  bundle install
  bundle exec buildpack-packager --cached --use-custom-manifest manifest-yahoo.yml
  VERSION=$(git describe --abbrev=0 --tags)
popd

TIMESTAMP=$(date +%s)

CACHED_BUILDPACK="buildpack-master/${BINARY_NAME}_buildpack-cached-*.zip"
CACHED_TIMESTAMP_BUILDPACK="buildpack-artifacts/${BINARY_NAME}_buildpack-cached-$VERSION+$TIMESTAMP.zip"

mv ${CACHED_BUILDPACK} ${CACHED_TIMESTAMP_BUILDPACK}

echo md5: "`md5sum $CACHED_TIMESTAMP_BUILDPACK`"
echo sha256: "`sha256sum $CACHED_TIMESTAMP_BUILDPACK`"
