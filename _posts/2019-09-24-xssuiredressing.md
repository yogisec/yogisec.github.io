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

### What is UI Redressing?
Redressing leverages features of html5 to call the history.replaceState or history.pushState functions to the browser. These functions allow a script to re-write what is presented in the URL bar after a page has loaded.

A script, rewrites the url presented in the address bar after loading the page. I'll let that sink in for a minute.
I first came across this method randomly on swisskyrepo's xss injection GitHub page.

From the example on the swisskyrepo's page history.replaceState() is leveraged to replace the page with a /login. 
*Note: history.pushState() could also be used.*

When the script is ran the url bar will be re-written from: 
```
http://dvwa/vulnerabilities/xss_r/?name=yogi#
```
to something a bit more devious
```
http://dvwa/login
```

So what? Whats the big deal, the url is re-written but the page is still the page it should be. Right? Maybe, unless the page gets changed with the document.body.innerHTML property...