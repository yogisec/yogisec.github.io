---
layout: post
title: XSS UI Redressing
date:   2019-09-23 12:00:00
categories: web
permalink: "/web/xss-ui-redirection"
---

## Moving Beyond alert('xss')

Most people know all about making an alert box pop or getting a cookie sent to an external site with document.cookie. It makes since, it is easy to demo and for the most part makes for a great proof of concept. 
Unfortunately these sometimes fail to showcase some of the more potentially devious outcomes from having a site that is vulnerable to XSS.
I recently came across a form of XSS that is called ui redressing. As I researched and learned more about it I came to see how malicious a XSS attack could be.