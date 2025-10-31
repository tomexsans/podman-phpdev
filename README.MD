# What is This?
## A LARAVEL Development Environment that uses PODMAN
- PHP 8 latest
- PostGresql
- Nginx
- Memcached
- Supervisor


## Why PODMAN?
- Podman is Lighter,Faster and is deamonless

## Podman must be installed!
- https://podman.io/

## Podman Registries must be set
```
unqualified-search-registries = ['docker.io','ghrc.io','quay.io']
```
- can be added to the following files:
- Option 1: create or update `$HOME/.config/containers/registries.conf`
- Option 2: update `/etc/containers/registries.conf`
- i would prefer the option 1 for cleaner

## How To Use


### Manual Download
- copy the `init.sh` on your directory
- using curl
- `curl https://raw.githubusercontent.com/tomexsans/podman-phpdev/refs/heads/main/init.sh > init.sh`
- using wget
- `wget https://raw.githubusercontent.com/tomexsans/podman-phpdev/refs/heads/main/init.sh`
- make it executable `chmod +x init.sh`
- configure the bash file for paths Especially the sourceFiles path
- the Bash script will automatically generate `index.php` and `index.html` file on the `${srcPath}/html` directory. Remove or comment out if you don't want to overwrite existing files
- execute the file `bash init.sh` or `./init.sh`
- this will create a new directory called config

Config is where you place files to configure each
```
config
├── nginx
│   └── config
│       └── default.conf
├── php
│   └── config
│       ├── custom.ini
│       └── php-fpm.conf
├── postgres
    └── config
└── supervisor
    └── config
        └── supervisord.conf
```

## NGINX not Running after init.sh?
- after the `init.sh` nginx may be down because of dependencies which are not yet done loading.
- Just start it manually


## Check
```bash
# list running
podman ps

# List pods
podman pod list

# want to enter a container?
podman exec -ti <container name> bash

```


## Tired of CLI? Try Using Podman desktop
- Podman has a GUI https://podman-desktop.io/
![View the Pods](img/image2.png)
![Usage on Podman Desktop](img/image.png)



## POD wont start after HOST reboot
- the command `sudo sysctl net.ipv4.ip_unprivileged_port_start=80` is just for the current session
- a fix would be to add the config permanently

```bash
# open conf
sudo nano /etc/sysctl.conf
# Add this line to the end or check if it exists 
net.ipv4.ip_unprivileged_port_start=80
# restart systl
sudo sysctl -p
# check if exists
sysctl net.ipv4.ip_unprivileged_port_start
```

## license?
- Free to Use! 
- Free to Fork!
- Free to modify!
- Free to do what you want :D