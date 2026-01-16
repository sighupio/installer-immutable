# Ansible Roles

This directory contains Ansible roles for deploying and managing a Kubernetes cluster on Flatcar Container Linux using systemd extensions (sysext).

## Design Decisions

### Why We Don't Use Ansible Handlers

This project deliberately avoids using Ansible handlers for service management in infrastructure roles (containerd, etcd, keepalived). Instead, these roles use inline conditional execution for service restarts.

**Rationale:**

Infrastructure services like containerd, etcd, and keepalived form critical dependencies for subsequent roles in the deployment. For example, containerd must be fully operational before Kubernetes components can start, and etcd must be running before control plane initialization. Using inline service restarts with immediate health verification ensures these services are ready before dependent tasks execute.

Handlers in Ansible execute at the end of a play and can be suppressed if any task fails. This deferred execution model doesn't work well for foundational services where dependent roles need guarantees that services are restarted and operational. Inline restarts make the control flow explicit and predictable, making it easier to debug issues and understand exactly when services are restarted.

The pattern used is straightforward: register configuration changes, set a restart flag combining multiple conditions using `set_fact`, then conditionally restart the service and verify its health inline. This ensures configuration changes are applied immediately and services are verified ready before proceeding.

**Note:** The kube-control-plane and kube-worker roles still use handlers for kubelet management, as kubelet restarts don't block subsequent role execution and benefit from handler aggregation across multiple configuration changes.
