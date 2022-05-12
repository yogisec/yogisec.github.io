---
title: 'what_is_cloudgoat'
date: 2018-11-28
# weight: 1
tags: ["aws", "cloud", "cloudgoat", "walkthrough", "ctf"]
categories: ["cloudgoat"]
aliases: ["/what-is-cloudgoat"]
author: "Travis"
summary: "Cloud Goat CTF Overview"
---
---
### First
CloudGoat was created by the RhinoSecurity Group.

### What is CloudGoat?
According to the [github repo](https://github.com/RhinoSecurityLabs/cloudgoat) "CloudGoat is Rhino Security Labs' "Vulnerable by Design" AWS deployment tool."

CloudGoat is a collection of terraform configuration files that when deployed create very specific, and very vulnerable aws environments.

The documentation in the repository walks through the setup process.

This tool removes the complexity of having to setup an environment. More importantly it provides and opportunity to blindly (mostly) work through the enumeration portion of an assessment

When finished with a scenerio you simply issue the destroy command and the entire environment is removed.