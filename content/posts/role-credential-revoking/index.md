---
title: 'role_credential_revoking'
date: 2018-11-28
tags: ["aws", "cloud", "dfir"]
categories: ["aws"]
aliases: ["/role-credential-revoking"]
author: "Travis"
summary: "IAM roles can have all current credentials revoked. This can be great to stop an attacker, but at what cost?"
---
---

The conversation came up about revoking credentials for a role associated which had ec2 instances associated with it. Does it impact the instance at all? When will the instance refresh its access keys? Is there just a blip in the EC2's access to AWS API calls or is it unable to make calls until its keys TTL ends? These were all questions that we did not know the answer to. The official Amazon docs here and here don't necessarily cover the fall out or recovery from this action.

You may ask yourself, if an EC2 instance with a role associated with it was compromised why would you want to revoke credentials from it and then turn around and provide the instance with a new set of keys and the same level of access it previously had? This is a valid point, but sometimes the business needs a service running. Perhaps it is making lots of money, or perhaps it is high visibility to the businesses brand. Sometimes the only choice which makes sense is to try and mitigate the issue without impacting production.

---

### The Setup

For the experiement below I have an EC2 instance with a role that permits it to access S3. The process flow is:

1. Query S3 validate everything is working
2. Revoke active sessions for the role, we should see the S3 queries begin to fail
3. Remove the instance profile from the instance, our access key should change, and S3 queries should continue to fail
4. Reapply the instance profile granting s3 access, our acess key should change once again, and the S3 queries should be successful

---

### Test 1

I built a python script to query the meta data service, determine the pertinent information about the access key currently associated with the instance, leverage boto3 to make a call to s3 and list the buckets. The script counts the number of buckets and prints all of the information to the screen if successful. If the script fails it shows the key and a failure message. The first script is below:

```python
import requests
import boto3
import time
import sys

def main():
  try:
    while True:
      s3_client = boto3.client('s3')
      response = requests.get('http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance/')
      response = response.json()
      expiration = response['Expiration']
      last_update = response['LastUpdated']
      token = response['Token']
      accesskey = response['AccessKeyId']
      try:
        s3_response = s3_client.list_buckets()
        number_of_buckets = len(s3_response['Buckets'])
        response_code = s3_response['ResponseMetadata']['HTTPStatusCode']
        print(f'AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update} -- ResponseCode: {response_code} -- NumberofBuckets: {number_of_buckets}')
      except:
        print(f'Keys no longer valid -- AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update}')
        pass
      time.sleep(1)
    except KeyboardInterrupt:
      print('\n Bye')
      sys.exit()

if __name__ == "__main__":
  main()
```

I started the script above, and everything seemed to be working as expected. What is interesting about this script is that didn't have the initial outcome I expected. Despite the meta-data service showing a refresh to the keys, it apepared that boto3 did not. It acted as if everything was a single session. In my initial coding of the script I assumed that since I was creating a new client with each call this would not have been a problem. To work around the problem I reworked the script.

---

### Test 2

For test 2 I modifed the code to manually define the credentials for the s3 client (lines 16-21) by using the values from the meta data response.

{{< highlight python "linenos=table,hl_lines=16-21,linenostart=1" >}}
import requests
import boto3
import time
import sys

def main():
  try:
    while True:
      response = requests.get('http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance/')
      response = response.json()
      expiration = response['Expiration']
      last_update = response['LastUpdated']
      token = response['Token']
      secret = response['SecretAccessKey']
      accesskey = response['AccessKeyId']
      s3_client = boto3.client(
       's3',
       aws_access_key_id=accesskey,
       aws_secret_access_key=secret,
       aws_session_token=token)
       )
      try:
        s3_response = s3_client.list_buckets()
        number_of_buckets = len(s3_response['Buckets'])
        response_code = s3_response['ResponseMetadata']['HTTPStatusCode']
        print(f'AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update} -- ResponseCode: {response_code} -- NumberofBuckets: {number_of_buckets}')
      except:
        print(f'Keys no longer valid -- AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update}')
        pass
      time.sleep(1)
    except KeyboardInterrupt:
      print('\n Bye')
      sys.exit()

if __name__ == "__main__":
  main()
{{< / highlight >}}

Once again, this failed. Unexpectidly it still appeared that the boto client was retaining the original credentials. After doing some digging it appears that this is true, even though I am setting the credentials with each iteration, boto3 apparently still caches the session. The only way to work around this is to create a new session with botocore.

---

### Test 3

I rewrote the script to leverage botocore.session and ended up with the code below:

{{< highlight python "linenos=table,hl_lines=16-18,linenostart=1" >}}
import requests
import boto3
import time
import sys

def main():
  try:
    while True:
      response = requests.get('http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance/')
      response = response.json()
      expiration = response['Expiration']
      last_update = response['LastUpdated']
      token = response['Token']
      secret = response['SecretAccessKey']
      accesskey = response['AccessKeyId']
      s3_session = ''
      s3_session = botocore.session.get_session()
      s3_client = s3_session.create_client('s3', region_name='us-east-1')
      try:
        s3_response = s3_client.list_buckets()
        number_of_buckets = len(s3_response['Buckets'])
        response_code = s3_response['ResponseMetadata']['HTTPStatusCode']
        print(f'AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update} -- ResponseCode: {response_code} -- NumberofBuckets: {number_of_buckets}')
      except:
        print(f'Keys no longer valid -- AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update}')
        pass
      time.sleep(1)
    except KeyboardInterrupt:
      print('\n Bye')
      sys.exit()

if __name__ == "__main__":
  main()
{{< / highlight >}}

Now when I ran the script, each new loop was ACTUALLY get new credentials and not leveraging cached ones. The process worke just as it should and I recieved the outputs below as I progressed through each stage.

```bash
AccessKeyId: ASIA4NX323S76LIV -- Expiration: 2020-07-04T20:23:29Z -- LastUpdated: 2020-07-04T14:13:19Z -- ResponseCode: 200 -- NumberofBuckets: 9
```

Revoke the role credentials in IAM.

```bash
Keys no longer valid -- AccessKeyId: ASIA4NX323S76LIV -- Expiration: 2020-07-04T20:23:29Z -- LastUpdated: 2020-07-04T14:13:19Z -- Exception: An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied
```

Remove the role to generate a new set of credentials instead of waiting for the old credentials to expire sometime within the next 12 hours.

```bash
Keys no longer valid -- AccessKeyId: ASIA4NX325UZ6YFR -- Expiration: 2020-07-04T20:25:21Z -- LastUpdated: 2020-07-04T14:16:02Z -- Exception: Unable to locate credentials
```

Re-apply the role to the ec2 instance and generate yet another set of credentials.

```bash
AccessKeyId: ASIA4NX3WW2QDQ5K -- Expiration: 2020-07-04T20:42:54Z -- LastUpdated: 2020-07-04T14:17:33Z -- ResponseCode: 200 -- NumberofBuckets: 9
```

---

### Key Takeaways

The behavior of the scripts was very interesting and should not be taken lightly. I would assume there is a high chance that any scripts running on an EC2 instance would be written in a way similar to the script in the first test. If as an IR team we revoked the credentials for the role (due to compromise), removed the instance profile, and then reapplied the profile in an effort to maintain 'uptime' for the business process it may still cause an outage because the client has cached credentials.

Rebooting the instance may fix this issue, but at that point you've still rebooted the instance potentially causing an outage. Obviously the best case scenario is to fully remediate before having the instance available again, but sometimes the businesses needs outweigh the risk.