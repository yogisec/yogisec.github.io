---
title: 'thing1!'
date: 2018-11-28T15:14:39+10:00
---

[More Markdown](https://www.markdownguide.org/basic-syntax/)


1. First item
2. Second item
3. Third item
    1. Indented item
    2. Indented item
4. Fourth item

- First item
- Second item
- Third item
    - Indented item
    - Indented item
- Fourth item

**so bold**

*italics can be used like this*

### Code

```json
{
  "firstName": "John",
  "lastName": "Smith",
  "age": 25
}
```


Turn off line numbers:

```json {linenos=false}
{
  "firstName": "John",
  "lastName": "Smith",
  "age": 25
}
```

How to highlight lines:

{{< highlight json "linenos=table,hl_lines=1 3-4,linenostart=1" >}}
{
  "firstName": "John",
  "lastName": "Smith",
  "age": 25
}
{{< / highlight >}}