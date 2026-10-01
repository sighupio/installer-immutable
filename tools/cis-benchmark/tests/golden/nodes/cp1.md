# CIS benchmark report: cp1

| Field | Value |
| --- | --- |
| Host | cp1.example.test |
| Role | control-plane |
| Targets | master,etcd,controlplane,node |
| Benchmark | cis-1.12 |
| kube-bench version | 0.12.0 |
| Date (UTC) | 2026-09-27T16:21:09Z |

## Totals

| Target | Section | Description | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- | --- |
| master | 1 | Control Plane Security Configuration | 53 | 0 | 3 | 4 |
| etcd | 2 | Etcd Node Configuration | 7 | 0 | 0 | 0 |
| controlplane | 3 | Control Plane Configuration | 1 | 0 | 1 | 3 |
| node | 4 | Worker Node Security Configuration | 20 | 0 | 1 | 4 |
| Total |  |  | 81 | 0 | 5 | 11 |

## Failures

None.

## Warnings

### 1.2.20 Ensure that the --request-timeout argument is set as appropriate (Manual)

Remediation:

```text
Edit the API server pod specification file $apiserverconf
and set the below parameter as appropriate and if needed.
For example, --request-timeout=300s
```

### 1.2.27 Ensure that the --encryption-provider-config argument is set as appropriate (Manual)

Remediation:

```text
Follow the Kubernetes documentation and configure a EncryptionConfig file.
Then, edit the API server pod specification file $apiserverconf
on the control plane node and set the --encryption-provider-config parameter to the path of that file.
For example, --encryption-provider-config=</path/to/EncryptionConfig/File>
```

### 1.2.28 Ensure that encryption providers are appropriately configured (Manual)

Remediation:

```text
Follow the Kubernetes documentation and configure a EncryptionConfig file.
In this file, choose aescbc, kms or secretbox as the encryption provider.
```

### 3.1.2 Service account token authentication should not be used for users (Manual)

Remediation:

```text
Alternative mechanisms provided by Kubernetes such as the use of OIDC should be implemented
in place of service account tokens.
```

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

## Declared skips

### 1.1.7 Ensure that the etcd pod specification file permissions are set to 600 or more restrictive (Automated)

### 1.1.8 Ensure that the etcd pod specification file ownership is set to root:root (Automated)

### 1.2.1 Ensure that the --anonymous-auth argument is set to false (Manual)

### 1.2.11 Ensure that the admission control plugin AlwaysPullImages is set (Manual)

### 3.1.1 Client certificate authentication should not be used for users (Manual)

### 3.1.3 Bootstrap token authentication should not be used for users (Manual)

### 3.2.2 Ensure that the audit policy covers key security concerns (Manual)

### 4.1.3 If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)

### 4.1.4 If proxy kubeconfig file exists ensure ownership is set to root:root (Manual)

### 4.2.9 Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)

### 4.2.14 Ensure that the --seccomp-default parameter is set to true (Manual)

## Raw result

[../raw/cp1.json](../raw/cp1.json)
