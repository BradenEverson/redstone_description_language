#!/bin/bash

if ! zig build; then
    echo "Build failed, exiting."
    exit 1
fi

sudo mv zig-out/bin/rhdl /usr/local/bin
