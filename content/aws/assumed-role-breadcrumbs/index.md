---
title: 'assumed_role_breadcrumbs'
date: 2018-11-28
tags: ["aws", "cloud", "dfir"]
weight: 3
categories: ["aws"]
aliases: ["/assume-role-breadcrumbs"]
author: "Travis"
summary: "Cloudtrail events in AWS offer a lot of visibility into the calls that roles leverage within the platform. Sometimes tracking the original source of the activity can be challenging. When users and other aws services from one account assume role into another hunting the origin can take a bit of backtracking."
---



---

Cloudtrail events in AWS offer a lot of visibility into the calls that roles leverage within the platform. Sometimes tracking the original source of the activity can be challenging. When users and other aws services from one account assume role into another hunting the origin can take a bit of backtracking.

---

### 
The Scenario
Let's set up a scenario, and work backwards through the logs. For this scenario we'll pretend that we are alerted to an anomalous api call. This anomaly is a call to the STS get-caller-identity endpoint. The principal ID `AROA5B64I5MBKOV6DYPCR` has never made a call to this endpoint. The full raw event is below. Next we'll begin to disscet it.

![raw_sts](images/raw_event.png  "img-fluid")

Digging into this, there are several fields that as an analyst are important to us while we try to unravel the intent behind this call. Lets break them down a bit:

|Field	|Value	|Event Description|
|---|---|---|
|type|	AssumedRole|	The type of the identity. AssumedRole = temporary credentials made with a role assumption. [Learn More](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html)|
|principalId|	AROA5B64I5MBKOV6DYPCR:power-lambda-session|	This is a unique identifer for the session.|
|eventSource|	sts.amazonaws.com|	This is the service in AWS that was leveraged.|
|eventName|	GetCallerIdentity|	This is the action that was called.|
|sourceIPAddress|	3.208.93.89|	Where the action call came from|
|userName|	power-users-lambda|	The role being leveraged. This field changes purpose, and location depending on the value of the type field. [Learn More](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html)|

Now that we have some basic information about what occured we can continue our analysis. At this point we have a basic understanding of the API call that was made. We know where the calls came from (sploier its an amazon ip) and we also know the role that made the call. At this point I would pivot off of the principalId to see what other calls were made. Our initial alert fired because the GetCallerIdentity call had never been made before. What if other calls were made that had previously been made from this same principal, but this time they were made with a malicious intent?

Luckily for us, after further analysis we find that no additional calls were made. We're still missing pieces to this puzzle however, who made this call and where in AWS did it actually come from?

---

### Who Made the Call?

To understand where and who made this call we need to find the inital authentication event tied to this session. We can do that by searching for the `eventSource: sts.amazonaws.com` and `eventName: AssumeRole` event in the CloudTrail logs. Its likely that there are going to be several of these events. These occur anytime something leverages a role within the account.

We need to somehow correlate an event (`GetCallerIdentity`) to an assume role action. To do that there are several fields that can help. In the picture below I've called them out with arrows.

![raw_assumerole](images/assumerole.png)

One of the best ways to narrow and better correlate events is with time. Its not foolproof, but it can be a good starting point. The best correlation points are going to be the accessKeyId and the assumeRoleID. Also make note, if you're searching these logs in splunk, kibana, etc. the first event for this principal ID depending on how you've filtered will likely be this event.

Once we have the AssumeRole event the information we are looking for which answers the 'where?' and 'who?' exists within the `userIdentity` value. In the picture above we can see that the userIdentity has three values:


|Field|	Value|	Event Description|
|---|---|---|
|type	|AWSAccount|	The request came from another AWS account. [Learn More](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html)|
|principalId|	AROA6OTNF75AHUEQU2DWT:sts-tester|	This is the principalId of the role in the foreign aws account that made the request.|
|accountId|	1212121212121|	This is the account where the assume role request origninated from|


Now we know: what was done, who did it, and where the request originated. The next step is start analyzing the Cloudtrail events the `12121212121212` account. We will determine if the activity we were first alerted on was a result of malicious activity occuring or someone trying something new.

---

### Initial AssumeRole Request

To confirm what we think we know from our previous event, lets look for the initiating assume role event. This will allow us to confirm that the event originated in account `12121212121212` and confirm the resource that made the request. We can find this initial event by searching for a few key vaules.
- The principalId that we discovered within the userIdentity key in the previous event: `AROA6OTNF75AHUEQU2DWT:sts-tester`
- The assumeRole eventname: `AssumeRole`
- The accesKeyId in the responseElement: `ASIA5X73I5MBJI37NG6J`

![raw_initialassumerole](images/initial_assume_request.png )

The event that we discover (pictured above) provides us with several pieces of context and confirmation. We now know without a doubt that the request came from this account and that we have the correct principal. We can use this information to find the resource within the account and do futher investigation.

How can we tell what the resource is? For these cloudtrail logs its fairly evident through the names that this is tied to a Lambda. But what if the name did not give it away so easily? Do we rummage through every possible endpoint that could make this call?

Looking at the userAgent field is one way we can determine what the resource is. Bare in mind that this is not 100% and the user agent could be changed or perhaps it does not give the resource away quite like the event we're looking at.

Another way is to look at the role that is being leveraged by the principal. In our event the role being leveraged by the lambda can be seen by looking sessionIssuer values. The friendly name of the role being leveraged can be found within the userName field:

![raw_initialassumerole](images/session_issuer.png)

All of the information within `sessionIssur` can be helpful, in our case the friendly name of `power-users-lambda` is enough for us. We can now pivot to the IAM roles section of aws within the `12121212121212` account and search for our `power-users-lambda` role. The results  of that search are below:

![raw_trustedentities](images/trusted_entities.png)

The important field here, is the trusted entities column. In this case it shows AWS service: lambda. This tells us that this role can only be used by Lambda scripts. We can quickly bounce over to the lambda section and find our resource. The name of the lambda is sts-tester which we discovered earlier in our principalId within the userIdentity key.

With the Lambda discovered we can analyze the code, find the resource owner and ask them if the behavior is expected. If it is not we have additional digging to do to gain insight into how the lambda became compromised. Fortunatly for us, the developer who owned this lambda was merely attempting to understand how to leverage a lambda cross account.

Reference Docs:

- **https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html**
- https://docs.aws.amazon.com/IAM/latest/UserGuide/cloudtrail-integration.html
- https://aws.amazon.com/blogs/security/how-to-audit-cross-account-roles-using-aws-cloudtrail-and-amazon-cloudwatch-events/