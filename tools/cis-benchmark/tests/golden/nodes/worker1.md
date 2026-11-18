# CIS benchmark report: worker1

| Field | Value |
| --- | --- |
| Host | worker1.example.test |
| Role | worker |
| Targets | node |
| Benchmark | cis-1.12 |
| kube-bench version | 0.12.0 |
| Date (UTC) | 2026-09-27T16:21:09Z |

## Totals

| Target | Section | Description | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- | --- |
| node | 4 | Worker Node Security Configuration | 18 | 1 | 2 | 4 |
| Total |  |  | 18 | 1 | 2 | 4 |

## Failures

### 4.2.1 Ensure that the --anonymous-auth argument is set to false (Automated)

Remediation:

```text
If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
`false`.
If using executable arguments, edit the kubelet service file
$kubeletsvc on each worker node and
set the below parameter in KUBELET_SYSTEM_PODS_ARGS variable.
`--anonymous-auth=false`
Based on your system, restart the kubelet service. For example,
systemctl daemon-reload
systemctl restart kubelet.service
```

## Warnings

### 4.2.7 Ensure that the --hostname-override argument is not set (Manual)

Remediation:

```text
Edit the kubelet service file $kubeletsvc
on each worker node and remove the --hostname-override argument from the
KUBELET_SYSTEM_PODS_ARGS variable.
Based on your system, restart the kubelet service. For example,
systemctl daemon-reload
systemctl restart kubelet.service
```

### 4.2.10 Ensure that the --rotate-certificates argument is not set to false (Automated)

Remediation:

```text
If using a Kubelet config file, edit the file to add the line `rotateCertificates` to `true` or
remove it altogether to use the default value.
If using command line arguments, edit the kubelet service file
$kubeletsvc on each worker node and
remove --rotate-certificates=false argument from the KUBELET_CERTIFICATE_ARGS
variable.
Based on your system, restart the kubelet service. For example,
systemctl daemon-reload
systemctl restart kubelet.service
```

## Declared skips

### 4.1.3 If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)

### 4.1.4 If proxy kubeconfig file exists ensure ownership is set to root:root (Manual)

### 4.2.9 Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)

### 4.2.14 Ensure that the --seccomp-default parameter is set to true (Manual)

## Raw result

[../raw/worker1.json](../raw/worker1.json)
