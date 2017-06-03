# Multi Chef

A multi-host, multi-org, multi-user [knife.rb](https://docs.chef.io/config_rb_knife.html) and [Chef repository](https://docs.chef.io/chef_repo.html) suitable for use on a shared system.

```
Usage: multi_chef.rb [-h|--help]
Usage: multi_chef.rb [-m CHEFRC_MODE] [-c CHEF_HOME] [-a CHEF_HOST] -o CHEF_ORG -u CHEF_USER [-e CHEF_EMAIL]
    -c, --chef-home [CHEF_HOME]      Chef home
                                       Default: directory containing multi_chef.rb
    -a, --api-server [CHEF_HOST]     Chef API server hostname or IP
                                       Default: api.chef.io
    -m, --mode single|multi          Chef repo mode
                                       Default: single
    -o, --org-name CHEF_ORG          Chef organization name (required)
    -u, --chef-user CHEF_USERNAME    Chef username (required)
    -e, --chef-email CHEF_EMAIL      Chef email address (required)
                                       Default: git config user.email
    -h, --help                       Show this help
```

## Overview

Multi Chef has two components: the `multi_chef.rb` Ruby script which sets up the environment a la ChefDK's `chef shell-init` and a knife.rb. The following environment variables are managed by `multi_chef.rb` and consumed by knife.rb:
-   CHEFRC_MODE
-   CHEF_HOST
-   CHEF_REPO
-   CHEF_HOME
-   CHEF_ORG
-   CHEF_USER
-   CHEF_EMAIL

The CHEF_REPO variable is set as a useful shorthand for referencing the current `knife[:chef_repo_path]`. For example, `knife data bag from file foodatabag ${CHEF_REPO}/data_bags/foodatabag`.

__Warning!__ In addition to the above environmental variables, `multi_chef.rb` also writes Berkshelf configuration to `~/.berkshelf/config.json`.

## Getting Started

There are two usage modes for multi-chef: __single__ and __multi__.

### Single user install

Single mode is default and intended for use on non-shared systems (i.e. a personal laptop).

1.  Clone Multi Chef:

    ```bash
    git clone https://github.com/jbartko/multi_chef.git ~/multi_chef
    ```

1.  Issue the following eval statement, substituting your own values:

    ```bash
    eval "$(~/multi-chef/multi_chef.rb -a CHEF_HOST -o CHEF_ORG -u CHEF_USER)"
    ```

    This should result in output similar to:

    ```
    Create the directory structure with:
    	mkdir -p ~/multi_chef/{,.chef/}hosts/CHEF_HOST \
    	  ~/multi_chef/hosts/CHEF_HOST/CHEF_ORG/CHEF_USER/cookbooks \
    	  ~/multi_chef/cookbooks

    Then move CHEF_USER's client key to:
    	~/multi_chef/.chef/hosts/CHEF_HOST/CHEF_USER.pem
    ```

1.  _Follow the instructions._  
    With the user client key in the appropriate place, re-issue the same eval statement. Now its output should resemble:
    ```
    CHEF_REPO: ~/multi_chef/hosts/CHEF_HOST/CHEF_ORG/CHEF_USER
    ```

Your shell has been prepared by Multi Chef! Congratulations. It should now be possible to issue knife commands and to use the [`chef-switch`](#chef-switch) function to maneuver between different Chef organizations and API endpoints on the fly.

Optionally, place an eval statement in your ~/.bashrc after the ChefDK shell initialization, e.g.:

```bash
# .bashrc snippet...
eval "$(chef shell-init bash)"
eval "$(~/multi-chef/multi_chef.rb -a DEFAULT_CHEF_HOST -o DEFAULT_CHEF_ORG -u DEFAULT_CHEF_USER)"
# ...
```

### Multi user install

Multi mode is intended to be used on a shared multi-user system such as a Knife SSH gateway or bastion host with ChefDK available. Organizational cookbooks will be shared among users.

1.  Clone Multi Chef into a shared location such as `/usr/local` or `/opt`:

    ```bash
    sudo git clone https://github.com/jbartko/multi_chef.git /opt/multi_chef
    ```

1.  Set ownership and permissions of the hosts directories to a group identifying Chef users:

    ```bash
    sudo chown :chef-users /opt/multi_chef/{cookbooks,hosts}/ /opt/multi_chef/.chef/hosts/
    sudo chmod g+srwx /opt/multi_chef/{.chef/hosts,cookbooks,hosts}/
    ```

1.  If both the host and Chef are authenticating users from the same identity store, an `/etc/profile.d` script can be used to set up the environment for users logging into the host. For example:

    ```bash
    # If not running interactively, don't do anything
    case $- in
      *i*) ;;
        *) return;;
    esac

    # If user belongs to the chef-users group...
    if id | grep -q chef-users; then
      # create a Berkshelf directory
      if ! [ -e ~/.berkshelf ]; then
        mkdir -p ~/.berkshelf
      fi

      # source ChefDK environment
      eval "$(chef shell-init bash)"

      # strip domain, replace dots with underscores
      CHEF_USER=${USER%%@*}
      export CHEF_USER=${CHEF_USER//./_}

      # source Multi Chef
      eval "$(/opt/multi-chef/multi_chef.rb -m multi -a COMPANY_CHEF_HOST -o COMPANY_DEFAULT_CHEF_ORG -u $CHEF_USER)"
    fi

    ```

## `chef-switch`

Evaluating `multi_chef.rb` makes available the `chef-switch` shell function. It can be used as a shorthand to invoke `multi_chef.rb` without calling it by path.

With `chef-switch`, it is possible to easily change between Chef organizations:

```
chef-switch -o OTHER_CHEF_ORG -u CHEF_USER
```

Or between Chef API service endpoints:

```
chef-switch -a OTHER_CHEF_API -o YET_ANOTHER_CHEF_ORG -u DIFFERENT_CHEF_USER
```

### Advanced Usage Scenarios

#### Chef replication substitute

chef-switch can assist in copying assets between Chef servers as a poor man's [Chef server replication](https://docs.chef.io/server_replication.html). For example:

```
chef-switch -o CHEF_ORG -u CHEF_USER
knife download /cookbooks/apt
chef-switch -a OTHER_CHEF_SERVER -o OTHER_CHEF_ORG -u CHEF_USER
knife cookbook upload apt
```

#### Shared organizational Chef repository

To use this repo as a shared, versioned Chef repository, begin by deleting `hosts/.gitignore`, then change the repository remote.

#### Use with existing Chef repositories

It is not necessary to store Chef policy assets alongside multi_chef.rb. The `-c|--chef-home` option can specify a different Chef repository root.

```
chef-switch -c ~/dev-chef -o dev -u CHEF_USER
chef-switch -c ~/prod-chef -o prod -u CHEF_USER
```

## License

```
The MIT License (MIT)

Copyright (c) 2017 John Bartko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
