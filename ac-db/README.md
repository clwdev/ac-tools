# ac-db
_Just the DB Part of ac-update_

`ac-db` pulls out the DB downloading part out of the monolithic `ac-update` script. It doesn't load the DB, it just gets it on disk with minimal effort.

## Usage
```
ac-db <site-alias> <site-environment>
```

## Example
Given SiteName 'foo' with environments 'dev', 'test', 'prod':

```
ac-db foo dev
```

This will download the latest dev DB snapshot to your current directory.