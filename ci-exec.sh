#!/bin/bash -xe

BUNDLER_VERSION=1.0.18
RVM_GEMSET=ncs_config

if [ -z $RVM_RUBY ]; then
    echo "RVM_RUBY must be set"
    exit 1
fi

set +xe
echo "Initializing RVM"
source ~/.rvm/scripts/rvm
set -xe

# On the overnight build, reinstall all gems
if [ `date +%H` -lt 5 ]; then
    echo "Purging gemset to verify that all deps still exist"
    rvm $RVM_RUBY gemset delete $RVM_GEMSET
fi

RVM_CONFIG="${RVM_RUBY}@${RVM_GEMSET}"
set +xe
echo "Switching to ${RVM_CONFIG}"
rvm use $RVM_CONFIG
set -xe

which ruby
ruby -v

set +e
gem list -i bundler -v $BUNDLER_VERSION
if [ $? -ne 0 ]; then
  set -e
  gem install bundler -v $BUNDLER_VERSION
fi
set -e

bundle update

bundle exec rake ci:spec --trace
