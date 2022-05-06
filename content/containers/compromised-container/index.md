---
title: 'compromised_container'
date: 2022-05-05T15:14:39+10:00
---

---

This will be a two part post. One focusing on triaging and analysis of a container that has been compromised. The second part will dig into a malicious "mystery" container and cover analysis and understanding what it is doing. 


### PIDs

Before we get into the actual analysis lets start with a quick overview of how processes exist in containers. When you run PS inside a container you typically get a very short list of running processes, and not all of the processes that are currently running on the underlying host. This is due to one of the foundational compoents that make a container a container, namespaces. Linux namespaces *isolate* the proceses within containers. What does this look like in practice? Lets look.

Take for example the following line from a `ps aux` output ran on a host.

```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root        2954  0.0  0.0   4200   740 pts/1    S+   02:41   0:00 ping 8.8.8.8
```

We can see this process has a PID of 2954. Looking at pstree we can see this process is a child of bash, which is a child of containerd-shim

```
systemd(1)───containerd-shim(2396)───bash(2604)───ping(2954)
```

If we exec into the container and run the same ps commands we get a completely different pid:

```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         379  0.0  0.0   4200   740 pts/1    S+   02:41   0:00 ping 8.8.8.8
```

This is due to the Linux namespace restricting our view so we can only see processes that exist "within" the container. If we attempt to kill PID 2954 on the host from within the container we will get an error that no such process exists. We could however kill process 379 without any issue.

For a much more indepth explaination I highly reccommend the book Container Security: Fundamental Technology Concepts that Protect Containerized Applications by Liz Rice. Last I checked Aqua security was giving the ebook away for free.

### Carving the running container out
docker commit

### Dive


### Memory Analysis
lime -> volatility