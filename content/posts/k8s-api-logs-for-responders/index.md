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
- vulnerable service exposure
- exposed cloud credentials
- exposed dashboard
- exposed kubeconfig file
- compromised images 


---
### K8s Api Audit logs

On the surface the api audit logs can be a bit overwhelming. Much like any log source, the more you look at it and the more you work with it the easier it becomes to quickly digest the events. As a responder there are a few fields we will want to pay attention to. requestURI, sourceip, verb, user.username, userAgent.

|field|purpose|
|---|---|
|requestURI|This is the resource requested answering the 'what' was requested|
|sourceip|Where the request came from|
|verb|Answers the question was this creating/modifying a resource or querying information about a resource|
|user.username|'who' made the request|
|userAgent|This is the user agent of the application that made the request |

asdf

---
### Kubelet logs

---
### etcd

---
### host logs / security tools
