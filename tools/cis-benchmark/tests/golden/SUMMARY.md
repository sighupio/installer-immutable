# CIS benchmark summary: fixture

| Field | Value |
| --- | --- |
| Cluster | fixture |
| Kubernetes version | 1.36.4 |
| Benchmark | cis-1.12 |
| Fallback | 1.36 is not mapped by the profiles: it fell back to 1.35 |
| kube-bench version | 0.12.0 |
| Profiles source | https://github.com/sighupio/installer-on-premises |
| Profiles commit | `80fc521d4047aeb468eab8215b2e6cc571975bdc` |
| Date (UTC) | 2026-09-27T16:21:09Z |

## Result

| Result | Count |
| --- | --- |
| Nodes with a result | 3 of 4 |
| PASS | 106 |
| FAIL | 1 |
| WARN | 7 |
| INFO | 15 |
| Nodes without a result | 1 |

## Nodes

| Node | Role | Targets | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- | --- |
| [cp1](nodes/cp1.md) | control-plane | master,etcd,controlplane,node | 81 | 0 | 5 | 11 |
| [etcd1](nodes/etcd1.md) | etcd | etcd | 7 | 0 | 0 | 0 |
| [worker1](nodes/worker1.md) | worker | node | 18 | 1 | 2 | 4 |
| [worker2](nodes/worker2.md) | worker | node | no result | no result | no result | no result |

## Failures

| Check | Description | Nodes |
| --- | --- | --- |
| 4.2.1 | Ensure that the --anonymous-auth argument is set to false (Automated) | worker1 |

## Warnings

| Check | Description | Nodes |
| --- | --- | --- |
| 1.2.20 | Ensure that the --request-timeout argument is set as appropriate (Manual) | cp1 |
| 1.2.27 | Ensure that the --encryption-provider-config argument is set as appropriate (Manual) | cp1 |
| 1.2.28 | Ensure that encryption providers are appropriately configured (Manual) | cp1 |
| 3.1.2 | Service account token authentication should not be used for users (Manual) | cp1 |
| 4.2.7 | Ensure that the --hostname-override argument is not set (Manual) | cp1, worker1 |
| 4.2.10 | Ensure that the --rotate-certificates argument is not set to false (Automated) | worker1 |

## Nodes without a result

| Node | Error |
| --- | --- |
| [worker2](nodes/worker2.md) | Failed to connect to the host via ssh: connection timed out |
