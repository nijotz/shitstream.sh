#!/usr/bin/env shcov

set -o errexit

# Run tests, generating coverage reports
echo "Running tests, with coverage"
export SHCOV=1
bats tests

# Convert the coverage reports to HTML
echo "Converting to HTML"
shlcov /tmp/shcov/ html

# If running in Travis CI, setup an ssh key to upload reports
if [ -n "$TRAVIS_SSHKEY" ]; then
    echo "Setting up Travis for SSH"
    echo $TRAVIS_SSHKEY > ~/travis.key
    eval $(ssh-agent)
    ssh-add ~/travis.key
fi

# Upload reports to server
echo "Copying reports to server"
rsync -Privtn html/ travis@nijotz.com:/var/www/shitstream/coverage/
