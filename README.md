# wsman
[![Build Status](https://travis-ci.org/janost/wsman.svg?branch=master)](https://travis-ci.org/janost/wsman)


## Introduction
Tool for managing a simple multi-site PHP web hosting environment. Meant to be used on a stack built with [cfn-simple-webhost][cfn-simple-webhost].

## Installation

Download the tarball and unpack it to a directory. You can also build it like this:
```
shards install
crystal build --release -o wsman src/cli.cr
```

## Static build
You might want to statically build it in some cases, for example when you're building it on Arch, but shipping it to Ubuntu bionic, which has older shared libraries:  

With podman:
```
podman build --tag=wsman-build .
podman run --rm -it -v $PWD:/app -w /app wsman-build shards install
podman run --rm -it -v $PWD:/app -w /app wsman-build crystal build --static --release -o wsman src/cli.cr
```  
or with docker:  
```
docker build --tag=wsman-build .
docker run --rm -it -v $PWD:/app -w /app wsman-build shards install
docker run --rm -it -v $PWD:/app -w /app wsman-build crystal build --static --release -o wsman src/cli.cr
```

## Usage

```
wsman [tool] [command] [arguments]
```

### Tools

#### site

```
wsman site setup \<sitename\>
```
Generate site configurations for the given site.

##### options

|Name|Definition|
|---|---|
|--skip-solr|`Optional`- Skip Solr core install, even if it's configured. (default:false)|

```
wsman site setup_all
```
Generate site configurations.

```
wsman site setup_solr \<sitename\>
```
Generate site's solr configurations for the given site.

#### ci

```
wsman ci zipinstall -s \<sitename\> -z \<archive\>
```

Installs a zipped site artifact to the webroot.

##### options

|Name|Definition|
|---|---|
|-f, --force|`Optional`- Overwrite target directory. (default:false)|
|-s SITE, --site=SITE|`Required` - Main hostname of the site. This is also used as the directory name.|
|-z ZIP, --zip ZIP|`Required` - Path to the archive.|

```
wsman ci cleanup -s \<sitename\>
```

Cleans up a site from the server.

```
wsman ci cleanup_solr -s \<sitename\>
```

Cleans up a site's solr core from the server.

##### options

|Name|Definition|
|---|---|
|-s SITE, --site=SITE |`Required`- Main hostname of the site. This is also used as the directory name.|


## What does it do?

The tool iterates over all directories in `web_root_dir` (`/srv/www` by default) and performs the following:
- Generates nginx configuration for each site from internal (see `fixtures/templates`) or site-specific template (`<SITE_DIR>/templates`). Supports sites with and without TLS.
- Generates `docker-compose.yml` for each site from internal or site-specific template. The purpose of this is to run each site's php-fpm daemon in a separate docker container.
- Generates `awslogs` configuration for each site, so access and error logs are streamed to CloudWatch.
- Generates a systemd service for the docker-based php-fpm daemon for each site.
- Creates MySQL database, user and password for each site
- Generates site-specific environment files, which are picked up by the systemd services and passed on to the PHP environment running in docker.

## TODO
- Proper documentation. The tool is quite complex so currently the only way to figure out stuff is to read the source code.
- Design proper CLI interface.
- Clean up the code because it's quite messy.
- Write tests.


[cfn-simple-webhost]: https://github.com/janost/cfn-simple-webhost
