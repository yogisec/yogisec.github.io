---
title: 'kubernetes_checkpointing-feature'
date: 2022-06-11
tags: ["containers", "linux", "dfir", "kubernetes"]
categories: ["kubernetes"]
aliases: ["/k8s-pod-checkpointing"]
author: "Travis"
summary: "Exploring the checkpoint feature which was introduced as an alpha feature in 1.25"

---

---

With the 1.25 release of Kubernetes a new feature was released in alpha called checkpointing. This feature is designed to grab a stateful copy of a running container.

---
### K8s Checkpointing

There are several log sources in a Kubernetes environment. One of the best sources to use during an incident to determine what has occurred on a cluster are the api audit logs. These logs contain *all* of the requests made to query or modify objects in the cluster. On the surface the api audit logs can be a bit overwhelming. Much like any log source, the more you look at it and the more you work with it the easier it becomes to quickly digest the event data. As a responder there are a few fields we will want to pay attention to: requestURI, sourceIPs, verb, user.username, userAgent.

### Limitations

When I first read about this feature I thought the checkpoint request would source from a `kubectl` command, limited by RBAC permissions. I envisioned cluster maintainers creating a "responder" role which would enable the security team to grab images of running containers.

### How to automate it...

```bash
# docker
docker save container_id -o incident12-containerid

# containerd
ctr -n=k8s.io image export  xxx.tar  $imageList

# Checkpointing
curl -X POST https://kubetlet-api:10250/checkpoint/{namespace}/{pod}/{container}

curl -X POST -k --cacert ca.crt --key me.key --cert me.crt https://localhost:10250/checkpoint/dev/nettools/0ec4e55bc819bb1d49b9e73d9d599e90c7134d58de8e34799cdf3adac7e907ff


/dev/nettools/0ec4e55bc819bb1d49b9e73d9d599e90c7134d58de8e34799cdf3adac7e907ff
```


```json
{
  "output":"13:04:52.730542214: Notice A shell was spawned in a container with an attached terminal (user=root user_loginuid=-1 k8s.ns=dev k8s.pod=nettools container=0ec4e55bc819 shell=sh parent=runc cmdline=sh terminal=34816 container_id=0ec4e55bc819 image=docker.io/raesene/alpine-nettools) k8s.ns=dev k8s.pod=nettools container=0ec4e55bc819",
  "priority":"Notice",
  "rule":"Terminal shell in container",
  "source":"syscall",
  "tags":["container","mitre_execution","shell"],
  "time":"2022-08-20T13:04:52.730542214Z",
  "output_fields": {
    "container.id":"0ec4e55bc819",
    "container.image.repository":"docker.io/raesene/alpine-nettools"
    ,"evt.time":1661000692730542214,
    "k8s.ns.name":"dev",
    "k8s.pod.name":"nettools",
    "proc.cmdline":"sh",
    "proc.name":"sh",
    "proc.pname":"runc",
    "proc.tty":34816,
    "user.loginuid":-1,
    "user.name":"root"
  }
}
```