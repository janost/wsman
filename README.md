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
podman run --rm -it -v $PWD:/app -w /app wsman-build crystal build --static --release -o wsman src/cli.cr
```  
or with docker:  
```
docker build --tag=wsman-build .
docker run --rm -it -v $PWD:/app -w /app wsman-build crystal build --static --release -o wsman src/cli.cr
```

## Usage

Currently there is a single `generate` command supported by the program.
```
wsman generate
```

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