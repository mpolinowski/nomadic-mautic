# Deploy Mautic

[Mautic is an Open Source Marketing Automation](https://github.com/mautic) platform that provides you with the greatest level of audience intelligence, thus enabling you to make more meaningful customer connections. Use Mautic to engage your customers and create an efficient marketing strategy. It can be installed using the official [Docker Image](https://hub.docker.com/r/mautic/mautic).


<!-- TOC -->

- [Deploy Mautic](#deploy-mautic)
  - [Docker-Compose](#docker-compose)
  - [Hashicorp Nomad](#hashicorp-nomad)
    - [Complete Job File](#complete-job-file)

<!-- /TOC -->


## Docker-Compose


```yml
version: "3.9"

services:
  database:
    image: mariadb:latest
    container_name: mautic-db
    environment:
      MYSQL_ROOT_PASSWORD: mypassword
    ports:
      - "3306:3306"
    volumes:
      - database:/var/lib/mysql:rw
    restart: always
    networks:
      - mauticnet
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --sql-mode=""

  mautic:
    container_name: mautic
    image: mautic/mautic:v4-apache
    volumes:
      - mautic_data:/var/www/html:rw
    environment:
      - MAUTIC_DB_HOST=database
      - MAUTIC_DB_USER=root
      - MAUTIC_DB_PASSWORD=mypassword
      - MAUTIC_DB_NAME=mautic4
      - MAUTIC_DB_TABLE_PREFIX=mautic4
    restart: always
    depends_on:
      - database
    links:
      - database
    networks:
      - mauticnet
    ports:
      - "8888:80"

networks:
  mauticnet:

volumes:
  database:
  mautic_data:
```


> `docker-compose up -d`



## Hashicorp Nomad

In Nomad we first need to create the volumes on our host in _/etc/nomad.d/client.hcl_ and then define it here:


```bash
volume "mautic_db" {
    type      = "host"
    read_only = false
    source    = "mautic_db"
}

volume "mautic_data" {
    type      = "host"
    read_only = false
    source    = "mautic_data"
}
```


It can then be mounted into the container:


```bash
volume_mount {
    volume      = "mautic_db"
    destination = "/var/lib/mysql"
    read_only   = false
}

volume_mount {
    volume      = "mautic_data"
    destination = "/var/www/html"
    read_only   = false
}
```


### Complete Job File

```bash
job "mautic" {
  datacenters = ["dc1"]
    group "mautic" {
        
        network {
            mode = "host"
            port "tcp" {
                static = 3306
            }
            port "http" {
                static = 80
            }
        }

        update {
            max_parallel = 1
            min_healthy_time  = "10s"
            healthy_deadline  = "5m"
            progress_deadline = "10m"
            auto_revert = true
            auto_promote = true
            canary = 1
        }

        restart {
            attempts = 10
            interval = "5m"
            delay    = "25s"
            mode     = "delay"
        }

        volume "mautic_db" {
            type      = "host"
            read_only = false
            source    = "mautic_db"
        }

        volume "mautic_data" {
            type      = "host"
            read_only = false
            source    = "mautic_data"
        }

        service {
            name = "mautic-db"
            port = "tcp"
            tags = [
                "database"
            ]

            check {
                name     = "DB Health"
                port     = "tcp"
                type     = "tcp"
                interval = "30s"
                timeout  = "4s"
            }
        }

        service {
            name = "mautic-frontend"
            port = "http"
            tags = [
                "frontend"
            ]

            check {
                name     = "HTTP Health"
                path     = "/"
                type     = "http"
                protocol = "http"
                interval = "10s"
                timeout  = "2s"
            }
        }

        task "mautic-db" {
            driver = "docker"

            config {
                image = "mariadb:latest"
                ports = ["tcp"]
                network_mode = "host"
                force_pull = false
            }

            volume_mount {
                volume      = "mautic_db"
                destination = "/var/lib/mysql" # <-- inside container
                read_only   = false
            }

            env {
                MYSQL_ROOT_PASSWORD = "mypassword"
                MYSQL_USER = "mautic4"
                MYSQL_PASSWORD = "mypassword"
                MYSQL_DATABASE = "mautic4"
                CONTAINER_NAME = "127.0.0.1"
            }
        }

        task "mautic-frontend" {
            driver = "docker"

            volume_mount {
                volume      = "mautic_data"
                destination = "/var/www/html"
                read_only   = false
            }

            config {
                image = "mautic/mautic:v4-apache"
                ports = ["http"]
                network_mode = "host"
                force_pull = false
            }

            env {
              MAUTIC_DB_HOST = "127.0.0.1"
              MAUTIC_DB_USER = "mautic4"
              MAUTIC_DB_PASSWORD = "mypassword"
              MAUTIC_DB_NAME = "mautic4"
              MAUTIC_DB_TABLE_PREFIX = "mautic4"
            }

            resources {
                cpu    = 1000
                memory = 1024
            }
        }
    }
}
```


