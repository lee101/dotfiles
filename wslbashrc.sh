#!/bin/bash
# WSL-specific configurations

# Set DISPLAY using the nameserver in /etc/resolv.conf (WSL)
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0 

export GCM_INTERACTIVE=always