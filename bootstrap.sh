#!/usr/bin/env bash

curl -sL "$(curl -s https://api.github.com/repos/juno-fx/Juno-Bootstrap/releases/latest | grep browser_download_url | grep orion-install-helper | cut -d '"' -f 4)" | bash -