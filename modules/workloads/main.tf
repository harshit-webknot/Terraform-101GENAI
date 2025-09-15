# MongoDB Helm Release
resource "helm_release" "mongodb" {
  count = contains(keys(var.services), "mongodb") ? 1 : 0

  name       = "mongodb"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mongodb"
  version    = "13.18.5"
  namespace  = "default"

  values = [
    yamlencode({
      auth = {
        enabled = true
        rootUser = "admin"
        rootPassword = "mongodb-root-password"
        usernames = ["appuser"]
        passwords = ["mongodb-app-password"]
        databases = ["101genai"]
      }
      
      replicaSet = {
        enabled = true
        replicas = {
          secondary = var.services.mongodb.replicas - 1
          arbiter = 0
        }
      }
      
      persistence = {
        enabled = true
        storageClass = var.storage_class
        size = try(var.services.mongodb.storage.size, "20Gi")
        accessModes = try(var.services.mongodb.storage.access_modes, ["ReadWriteOnce"])
      }
      
      resources = var.services.mongodb.resources
      
      service = {
        type = "ClusterIP"
        ports = {
          mongodb = 27017
        }
      }
    })
  ]
}

# PostgreSQL Helm Release (for Keycloak)
resource "helm_release" "postgresql" {
  count = contains(keys(var.services), "postgres") ? 1 : 0

  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "12.12.10"
  namespace  = "default"

  values = [
    yamlencode({
      auth = {
        postgresPassword = "postgres-root-password"
        username = "keycloak"
        password = "keycloak-password"
        database = "keycloak"
      }
      
      primary = {
        persistence = {
          enabled = true
          storageClass = var.storage_class
          size = try(var.services.postgres.storage.size, "10Gi")
          accessModes = try(var.services.postgres.storage.access_modes, ["ReadWriteOnce"])
        }
        resources = var.services.postgres.resources
      }
      
      service = {
        type = "ClusterIP"
        ports = {
          postgresql = 5432
        }
      }
    })
  ]
}

# Redis Helm Release
resource "helm_release" "redis" {
  count = contains(keys(var.services), "redis") ? 1 : 0

  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "18.1.5"
  namespace  = "default"

  values = [
    yamlencode({
      auth = {
        enabled = true
        password = "redis-password"
      }
      
      master = {
        persistence = {
          enabled = true
          storageClass = var.storage_class
          size = try(var.services.redis.storage.size, "5Gi")
          accessModes = try(var.services.redis.storage.access_modes, ["ReadWriteOnce"])
        }
        resources = var.services.redis.resources
      }
      
      replica = {
        replicaCount = var.services.redis.replicas - 1
        persistence = {
          enabled = true
          storageClass = var.storage_class
          size = try(var.services.redis.storage.size, "5Gi")
          accessModes = try(var.services.redis.storage.access_modes, ["ReadWriteOnce"])
        }
        resources = var.services.redis.resources
      }
      
      service = {
        type = "LoadBalancer"
        ports = {
          redis = 6379
        }
      }
    })
  ]
}

# Weaviate Helm Release
resource "helm_release" "weaviate" {
  count = contains(keys(var.services), "weaviate") ? 1 : 0

  name       = "weaviate"
  repository = "https://weaviate.github.io/weaviate-helm"
  chart      = "weaviate"
  version    = "16.8.5"
  namespace  = "default"

  values = [
    yamlencode({
      replicas = var.services.weaviate.replicas
      
      persistence = {
        enabled = true
        storageClass = var.storage_class
        size = try(var.services.weaviate.storage.size, "32Gi")
        accessModes = try(var.services.weaviate.storage.access_modes, ["ReadWriteOnce"])
      }
      
      resources = var.services.weaviate.resources
      
      service = {
        type = "LoadBalancer"
        ports = {
          http = 80
          grpc = 50051
        }
      }
      
      modules = {
        "text2vec-openai" = {
          enabled = true
        }
        "generative-openai" = {
          enabled = true
        }
      }
    })
  ]
}

# Keycloak Deployment
resource "kubectl_manifest" "keycloak_deployment" {
  count = contains(keys(var.services), "keycloak") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "keycloak"
      namespace = "default"
      labels = {
        app = "keycloak"
      }
    }
    spec = {
      replicas = var.services.keycloak.replicas
      selector = {
        matchLabels = {
          app = "keycloak"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "keycloak"
          }
        }
        spec = {
          containers = [
            {
              name = "keycloak"
              image = "quay.io/keycloak/keycloak:22.0"
              args = ["start-dev"]
              env = [
                {
                  name = "KEYCLOAK_ADMIN"
                  value = "admin"
                },
                {
                  name = "KEYCLOAK_ADMIN_PASSWORD"
                  value = "admin"
                },
                {
                  name = "KC_DB"
                  value = "postgres"
                },
                {
                  name = "KC_DB_URL"
                  value = "jdbc:postgresql://postgresql:5432/keycloak"
                },
                {
                  name = "KC_DB_USERNAME"
                  value = "keycloak"
                },
                {
                  name = "KC_DB_PASSWORD"
                  value = "keycloak-password"
                }
              ]
              ports = [
                {
                  containerPort = 8080
                  name = "http"
                }
              ]
              resources = var.services.keycloak.resources
            }
          ]
        }
      }
    }
  })

  depends_on = [helm_release.postgresql]
}

resource "kubectl_manifest" "keycloak_service" {
  count = contains(keys(var.services), "keycloak") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "keycloak"
      namespace = "default"
    }
    spec = {
      selector = {
        app = "keycloak"
      }
      ports = [
        {
          port = 8080
          targetPort = 8080
          name = "http"
        }
      ]
      type = "ClusterIP"
    }
  })
}

# Backend Application Deployment
resource "kubectl_manifest" "backend_deployment" {
  count = contains(keys(var.services), "backend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "backend-app"
      namespace = "default"
      labels = {
        app = "backend-app"
      }
    }
    spec = {
      replicas = var.services.backend.replicas
      selector = {
        matchLabels = {
          app = "backend-app"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "backend-app"
          }
        }
        spec = {
          containers = [
            {
              name = "backend"
              image = "your-registry/backend:latest"
              ports = [
                {
                  containerPort = 8000
                  name = "http"
                }
              ]
              env = [
                {
                  name = "MONGODB_URL"
                  value = "mongodb://appuser:mongodb-app-password@mongodb:27017/101genai"
                },
                {
                  name = "REDIS_URL"
                  value = "redis://:redis-password@redis-master:6379"
                },
                {
                  name = "WEAVIATE_URL"
                  value = "http://weaviate:80"
                },
                {
                  name = "KEYCLOAK_URL"
                  value = "http://keycloak:8080"
                }
              ]
              resources = var.services.backend.resources
            }
          ]
        }
      }
    }
  })
}

resource "kubectl_manifest" "backend_service" {
  count = contains(keys(var.services), "backend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "backend-app"
      namespace = "default"
    }
    spec = {
      selector = {
        app = "backend-app"
      }
      ports = [
        {
          port = 8000
          targetPort = 8000
          name = "http"
        }
      ]
      type = "LoadBalancer"
    }
  })
}

# Frontend Application Deployment
resource "kubectl_manifest" "frontend_deployment" {
  count = contains(keys(var.services), "frontend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "frontend-app"
      namespace = "default"
      labels = {
        app = "frontend-app"
      }
    }
    spec = {
      replicas = var.services.frontend.replicas
      selector = {
        matchLabels = {
          app = "frontend-app"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "frontend-app"
          }
        }
        spec = {
          containers = [
            {
              name = "frontend"
              image = "your-registry/frontend:latest"
              ports = [
                {
                  containerPort = 5173
                  name = "http"
                }
              ]
              env = [
                {
                  name = "VITE_API_URL"
                  value = "http://backend-app:8000"
                },
                {
                  name = "VITE_KEYCLOAK_URL"
                  value = "http://keycloak:8080"
                }
              ]
              resources = var.services.frontend.resources
            }
          ]
        }
      }
    }
  })
}

resource "kubectl_manifest" "frontend_service" {
  count = contains(keys(var.services), "frontend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "frontend-app"
      namespace = "default"
    }
    spec = {
      selector = {
        app = "frontend-app"
      }
      ports = [
        {
          port = 5173
          targetPort = 5173
          name = "http"
        }
      ]
      type = "LoadBalancer"
    }
  })
}

# Celery Worker Deployment
resource "kubectl_manifest" "celery_deployment" {
  count = contains(keys(var.services), "celery") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "celery-worker"
      namespace = "default"
      labels = {
        app = "celery-worker"
      }
    }
    spec = {
      replicas = var.services.celery.replicas
      selector = {
        matchLabels = {
          app = "celery-worker"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "celery-worker"
          }
        }
        spec = {
          containers = [
            {
              name = "celery-worker"
              image = "maniniabhi/celery-worker:latest"
              env = [
                {
                  name = "CELERY_BROKER_URL"
                  value = "redis://:redis-password@redis-master:6379/0"
                },
                {
                  name = "CELERY_RESULT_BACKEND"
                  value = "redis://:redis-password@redis-master:6379/0"
                },
                {
                  name = "MONGODB_URL"
                  value = "mongodb://appuser:mongodb-app-password@mongodb:27017/101genai"
                }
              ]
              resources = var.services.celery.resources
            }
          ]
        }
      }
    }
  })
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = var.provider == "aws" ? {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          } : {
            "cloud.google.com/load-balancer-type" = "External"
          }
        }
        
        resources = {
          requests = {
            cpu = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]
}

# Ingress for services
resource "kubectl_manifest" "main_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind = "Ingress"
    metadata = {
      name = "main-ingress"
      namespace = "default"
      annotations = {
        "kubernetes.io/ingress.class" = "nginx"
        "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      }
    }
    spec = {
      rules = [
        {
          http = {
            paths = [
              {
                path = "/api/(.*)"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "backend-app"
                    port = {
                      number = 8000
                    }
                  }
                }
              },
              {
                path = "/(.*)"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "frontend-app"
                    port = {
                      number = 5173
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [helm_release.nginx_ingress]
}
