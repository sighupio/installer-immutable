# `sysctl` Ansible Role

The `sysctl` Ansible Role allows setting Kernel parameters via the sysctl CLI.

The role will create a file where it will store the custom parameters so they are persisted and reapplied after a reboot.

>[!IMPORTANT]
> Due to the nature of `sysctl`, removing a parameter from the list won't reset it to its previous value.
>
> If you want to reset the value you will need to specify the old value in the parameters list (or reset it manually, for example by rebooting the nodes)
