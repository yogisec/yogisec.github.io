---
title: 'kubernetes_logs_for_responders'
date: 2022-06-11
tags: ["containers", "linux", "dfir", "kubernetes"]
categories: ["containkubernetesers"]
aliases: ["/k8s-api-logs-for-responders"]
author: "Travis"
summary: "An overview of the Kubernetes api logs. What fields are useful, and some places where log visibility might be missing in most environments."

---

---

An overview of the Kubernetes api logs. What fields are useful, and some places where log visibility might be missing in most environments. 

---
### Overview of Kubernetes Log Sources

There are several log sources in a Kubernetes environment which can be useful when responding to incidents. One of the best sources to determine what has occured on a cluster are the api audit logs. These logs contain *all* of the requests made to query or modify objects in the cluster.


---
### Ways k8s can be Compromised

https://www.microsoft.com/security/blog/2020/04/02/attack-matrix-kubernetes/
- anonymous user access
- secrets

---
### K8s Api Audit logs

On the surface the api audit logs can be a bit overwhelming. As a responder there are a few fields we will want to pay attention to. requestURI, sourceip, verb, user.username. 

---
### Kubelet logs

---
### etcd

---
### host logs / security tools
