#!/usr/bin/env bash

# Use `admin.conf` by default
[[ -f /etc/kubernetes/admin.conf ]] && export KUBECONFIG=/etc/kubernetes/admin.conf
# If `super-admin.conf` exist, use it instead
[[ -f /etc/kubernetes/super-admin.conf ]] && export KUBECONFIG=/etc/kubernetes/super-admin.conf
alias k="kubectl"
