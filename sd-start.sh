#!/usr/bin/env bash

# I want a shell script to "automate" the portal opening process. Both opening the branches, and imporantly supporting overrides
#
# `sd-start master` should open master branch with no overrides. Also support i.e. "feature-live-feed" instead of master
# `sd-start master --override luna mobileapi web` etc etc. Same syntax as ngrok start
# Should ideally integrate with the ngrok config directly, both for consistently naming and for getting the correct url 
#
# Which branches to show: Could either just be a config of relevant branches, just input any name and hope it works, or fetch relevant branches from azure. Like we do in list-branches
