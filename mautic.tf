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
