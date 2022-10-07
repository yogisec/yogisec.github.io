---
title: 'kubernetes_get_list_watch_permissions'
date: 2022-06-11
tags: ["containers", "linux", "dfir", "kubernetes"]
categories: ["kubernetes"]
aliases: ["/k8s-get-list-watch-permissions"]
author: "Travis"
summary: "An experiment diving into the differences between get, list, and watch permission sets. Where do they overlap, where are the boundaries?"

---

---

An experiment diving into the differences between get, list, and watch permission sets. Where do they overlap, where are the boundaries? 

---
### K8s Rbac Overview

### K8s Verbs

The Kubernetes API has 10 verbs: apply, create, delete, deletecollection, get, list, patch, proxy, update, and watch. Most are self explainitory, based on the name. Others may seem straight forward but have unexpected side effects. In this post we are going to focus on three of the verbs: `get`, `list`, and `watch`. The goal is to understand them better and to highlight potential unexpected permissions issues.

### The Environment
For this testing we have a kubernetes cluster running various things. We have a dedicated namespace called "permissions-test". Within the namespace we have three service accounts. Those service accounts are all associated with unique clusterroles granting a unique permission set. One role grants `get` access, another `list`, and the last grants `watch` access to resources in the cluster. For each test we will run the same subset of commands to paint a clear picture of what each verb is capable of. 

### K8s getter
Lets start by digging into the `get` permission. Below we have a ClusterRole which is tied to a service account in the `permissions-test` namespace.This ClusterRole grants the ability to `get` information about pods and secrets across the cluster.

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lister-role
  namespace: permissions-test
rules:
  - apiGroups:
        - "*"
    resources:
      - pods
      - secrets
    verbs: ["get"]
```

The service account is tied to the `getter` pod. If we exec into the pod we can use this service account to explore the permission boundaries of the "get" verb.



```
./kubectl -n permissions-test get pods
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:permissions-test:getter" cannot list resource "pods" in API group "" in the namespace "permissions-test"
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/pods?limit=500


```
./kubectl -n permissions-test get secrets
Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:permissions-test:getter" cannot list resource "secrets" in API group "" in the namespace "permissions-test"
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/secrets?limit=500


```
./kubectl -n permissions-test get pod getter
NAME     READY   STATUS    RESTARTS   AGE
getter   2/2     Running   0          10m
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/pods/getter

```
./kubectl -n permissions-test get secret api-key
NAME      TYPE     DATA   AGE
api-key   Opaque   1      6m57s
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/secrets/api-key

```bash
./kubectl -n permissions-test describe pod getter
Name:             getter
Namespace:        permissions-test
Priority:         0
Service Account:  getter
...
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/pods/getter


```bash
./kubectl -n permissions-test get secret api-key -o yaml
apiVersion: v1
data:
  api-key: d2VsbCBhcmVuJ3QgeW91IGN1cmlvdXMK
kind: Secret
...
```
https://100.64.0.1:443/api/v1/namespaces/permissions-test/secrets/api-key

### K8s lister
Resources                                       Non-Resource URLs                     Resource Names   Verbs

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lister-role
  namespace: permissions-test
rules:
  - apiGroups:
        - "*"
    resources:
      - pods
      - secrets
    verbs: ["list"]
```

```
./kubectl -n permissions-test get pods
NAME      READY   STATUS    RESTARTS   AGE
getter    2/2     Running   0          19m
lister    2/2     Running   0          19m
watcher   2/2     Running   0          19m
```

```
./kubectl -n permissions-test get secrets
NAME      TYPE     DATA   AGE
api-key   Opaque   1      16m
```

```
./kubectl -n permissions-test get secret api-key
Error from server (Forbidden): secrets "api-key" is forbidden: User "system:serviceaccount:permissions-test:lister" cannot get resource "secrets" in API group "" in the namespace "permissions-test"
```

```
./kubectl -n permissions-test get secrets -o yaml
apiVersion: v1
items:
- apiVersion: v1
  data:
    api-key: d2VsbCBhcmVuJ3QgeW91IGN1cmlvdXMK
  kind: Secret
```


### K8s watcher
```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lister-role
  namespace: permissions-test
rules:
  - apiGroups:
        - "*"
    resources:
      - pods
      - secrets
    verbs: ["watch"]
```
### Thoughts

There are several log sources in a Kubernetes environment. One of the best sources to use during an incident to determine what has occurred on a cluster are the api audit logs. These logs contain *all* of the requests made to query or modify objects in the cluster. On the surface the api audit logs can be a bit overwhelming. Much like any log source, the more you look at it and the more you work with it the easier it becomes to quickly digest the event data. As a responder there are a few fields we will want to pay attention to: requestURI, sourceIPs, verb, user.username, userAgent.

|field|purpose|
|---|---|
|requestURI|This is the resource requested answering the 'what' was requested|
|sourceip|Where the request came from|
|verb|Answers the question was this creating/modifying a resource or querying information about a resource|
|user.username|'who' made the request|
|userAgent|This is the user agent of the application that made the request |
|responseStatus.code| |
|annotations.authorization.k8s.io/decision|rbac decision, allow/forbid|
|annotations.authorization.k8s.io/reason|Description on why a request was allowed|
|user.extra.authentication.kubernetes.io/pod-name|pod where request originated|
|user.extra.authentication.kubernetes.io/pod-uid|pod uid where request originated|

Below is a sample api audit log event. 



---
### Kubelet logs

The kubelet is the control point for all the comings and goings on the node. Each node in the cluster will have a unique set of kubelet logs. Kubelet logs may be helpful when attempting to confirm when a particular container was started or removed. Depending on how it is configured the logs may have a lot of additional information available as well.

[This](https://docs.openshift.com/container-platform/4.6/rest_api/editing-kubelet-log-level-verbosity.html) page from RedHat has a handy reference chart for the different log levels available for the kubelet 

|Log verbosity|Description|
|---|---|
|--v=0|Always visible to an Operator.|
|--v=1|A reasonable default log level if you do not want verbosity.|
|--v=2|Useful steady state information about the service and important log messages that might correlate to significant changes in the system. This is the recommended default log level.|
|--v=3|Extended information about changes.|
|--v=4|Debug level verbosity.|
|--v=6|Display requested resources.|
|--v=7|Display HTTP request headers.|
|--v=8|Display HTTP request contents.|

At the time of writing kops deploys the kubelet with a default log level of 2 `/usr/local/bin/kubelet ... --v=2` unless otherwise specified. Below are some sample events that show a container being removed, the `nettools` pod being removed, and then a few seconds later the `nettools` pod being created.

```
Jun 18 19:42:16 ip-172-20-59-66 kubelet[5656]: {"ts":1655581336241.7104,"caller":"topologymanager/scope.go:110","msg":"RemoveContainer","v":0,"containerID":"9beafc9454c36cf07dec1793128629f2a80bb43ac65aac400458f44d398032a8"}

Jun 18 19:42:16 ip-172-20-59-66 kubelet[5656]: {"ts":1655581336244.2942,"caller":"kubelet/kubelet.go:2102","msg":"SyncLoop REMOVE","v":2,"source":"api","pods":[{"name":"nettools","namespace":"dev"}]}

Jun 18 19:42:34 ip-172-20-59-66 kubelet[5656]: {"ts":1655581354264.5642,"caller":"kubelet/kubelet.go:2092","msg":"SyncLoop ADD","v":2,"source":"api","pods":[{"name":"nettools","namespace":"dev"}]}
```

From a responder's point of view, these logs are more than likely not the most helpful but may be a good reference point. 

---
### host logs / security tools

Most hosts within a Kubernetes cluster are going to be Linux. This means that most if not all of the log sources traditionally used to analyze a Linux host can be used to help paint a picture of what has occurred on a compromised cluster. The same applies to 3rd party security tools. We briefly talked about Falco earlier, but other tools such has ossec, sysmon, osquery, and <$$ VENDOR> can all be used to gain more insights into the malicious activity. Please make sure to understand the limits of the tools though, especially when it comes to paid vendor solutions. A lot of the big players are much stronger in Windows and have gaps in visibility when it comes to *nix systems.

---
### Other places for logs
Depending on how the cluster is configured, and what support applications are being utilized there could be several additional places with valuable log information. Does the cluster use a service mesh, are there proxy containers deployed into every pod for the most part? If so, the proxy containers are great source of logs potentially. If it appears to be a pod or application compromise, do not forget to review the application logs and the logs for the application pod if it is still around.