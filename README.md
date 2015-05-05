Chef Build Domain Overview
---

[![Circle CI](https://circleci.com/gh/boxidau/chef-builddomainhelper.svg?style=svg)](https://circleci.com/gh/boxidau/chef-builddomainhelper)

Build Domains are designed to further sub-divide a Chef Environment into a smaller unit. The purpose of a build domain (BD) is to allow multiple customer code builds to exist in the same Chef environment.

A build domain is the logical boundary for chef searches for other nodes. This is so each build domain can have it's own ecosystem of servers (persistence, caching, api etc).

By creating logical separation the customer is able to create a new build environment (with a single heat command) where the particular customer code build revision can be specified before the environment is built. This results in disposable development environments where each development environment's "influence" is limited to it's own build domain.

Build domains have a very limited set of attributes which can be adjusted. This will usually be the customer code git ref (build, branch, SHA build ID, etc). Since there are a very limited set of attributes which vary between build domains the result is very repeatable builds.

Since build domains are separated and have limited influence on each other as well as being able to specify a particular customer git revision (only). Build domains lend themselves extremely well to blue-green deployments.

![Chef BD Overview](/images/chef-bd-overview.png "Chef BD Overview")

### Principals of Use

- chef recipes should look for defined attributes first (ie. node['customer']['mysql']['master_ip'])
  - This allows environment attribute_overrides to take precedence over chef searches
  - For production environment this allows fixed persistence layer for dynamic build environments
  - Attributes should *all* be explicitly set to `nil` to enable reliable overrides. Should you want to define an attribute value, this should be done via environment attributes
- chef searches should look something like this


### Anti-patterns

- Setting many variables per build domain should not be allowed this reduces repeatability of environments. Variables should be limited to customer code revision only

## How to setup build domains

Build domains do not have any sort of inbuilt functionality in Chef therefore is implemented entirely in user land.

A node is able to determine it's build environment by reading its own metadata tags from xenstore or if it is not a virtualised machine it can read a file at `/etc/build-domain` this will be abstracted away from any other recipes and results will be available via node.normal attributes.

```
{
  "build_domain_id": "xxxxxxxxxxx",
  "code_ref": "35973597359735973507253072935",
  "code_ref_type": "hash"
}
```

`build_domain_id` should be dynamically generated for all machines in the same build domain (ie. each machine in the build domain can find each other with this ID)

`code_ref` is the customer code build ref, this can be a commit hash, branch name (not recommended) or tag.

`code_ref_type` can be one of the following:
  - `hash`
  - `tag`
  - `branch`
