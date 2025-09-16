# MongoDB Secret - Now references external secret manager
resource "kubectl_manifest" "mongodb_secret" {
  count = var.services.mongodb.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
      name = "mongodb-secret"
      namespace = "default"
      annotations = {
        "external-secrets.io/secret-name" = var.secret_manager.secrets.mongodb_secret
        "external-secrets.io/cloud_provider" = var.secret_manager.cloud_provider
      }
    }
    type = "Opaque"
  })
}

# MongoDB StatefulSet
resource "kubectl_manifest" "mongodb_statefulset" {
  count = var.services.mongodb.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "StatefulSet"
    metadata = {
      name = "mongodb"
      namespace = "default"
      labels = {
        app = "mongodb"
      }
    }
    spec = {
      serviceName = "mongodb-headless"
      replicas = var.services.mongodb.replicas
      selector = {
        matchLabels = {
          app = "mongodb"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "mongodb"
          }
        }
        spec = {
          containers = [
            {
              name = "mongodb"
              image = "mongo:7.0"
              ports = [
                {
                  containerPort = 27017
                  name = "mongodb"
                }
              ]
              env = [
                {
                  name = "MONGO_INITDB_ROOT_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = "mongodb-secret"
                      key = "username"
                    }
                  }
                },
                {
                  name = "MONGO_INITDB_ROOT_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "mongodb-secret"
                      key = "password"
                    }
                  }
                },
                {
                  name = "MONGO_INITDB_DATABASE"
                  value = var.services.mongodb.env.MONGO_INITDB_DATABASE
                }
              ]
              resources = var.services.mongodb.resources
              volumeMounts = [
                {
                  name = "mongodb-data"
                  mountPath = "/data/db"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "mongodb-data"
              emptyDir = {}
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.mongodb_secret]
}

# MongoDB Service
resource "kubectl_manifest" "mongodb_service" {
  count = var.services.mongodb.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "mongodb-headless"
      namespace = "default"
      labels = {
        app = "mongodb"
      }
    }
    spec = {
      clusterIP = "None"
      selector = {
        app = "mongodb"
      }
      ports = [
        {
          port = 27017
          targetPort = 27017
          name = "mongodb"
        }
      ]
    }
  })
}

# MongoDB HPA
resource "kubectl_manifest" "mongodb_hpa" {
  count = var.services.mongodb.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "mongodb-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "StatefulSet"
        name = "mongodb"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# PostgreSQL Secret - Now references external secret manager
resource "kubectl_manifest" "postgres_secret" {
  count = var.services.postgres.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
      name = "postgres-secret"
      namespace = "default"
      labels = {
        app = "postgres"
      }
      annotations = {
        "external-secrets.io/secret-name" = var.secret_manager.secrets.postgres_secret
        "external-secrets.io/cloud_provider" = var.secret_manager.cloud_provider
      }
    }
    type = "Opaque"
  })
}

# PostgreSQL Deployment
resource "kubectl_manifest" "postgres_deployment" {
  count = var.services.postgres.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "postgres"
      namespace = "default"
      labels = {
        app = "postgres"
      }
    }
    spec = {
      replicas = var.services.postgres.replicas
      selector = {
        matchLabels = {
          app = "postgres"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "postgres"
          }
        }
        spec = {
          containers = [
            {
              name = "postgres"
              image = "postgres:15"
              ports = [
                {
                  containerPort = 5432
                  name = "postgres"
                }
              ]
              env = [
                {
                  name = "POSTGRES_USER"
                  valueFrom = {
                    secretKeyRef = {
                      name = "postgres-secret"
                      key = "username"
                    }
                  }
                },
                {
                  name = "POSTGRES_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "postgres-secret"
                      key = "password"
                    }
                  }
                },
                {
                  name = "POSTGRES_DB"
                  value = var.services.postgres.env.POSTGRES_DB
                },
                {
                  name = "PGDATA"
                  value = var.services.postgres.env.PGDATA
                }
              ]
              resources = var.services.postgres.resources
              volumeMounts = [
                {
                  name = "postgres-data"
                  mountPath = "/var/lib/postgresql/data"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "postgres-data"
              emptyDir = {}
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.postgres_secret]
}

# PostgreSQL Service
resource "kubectl_manifest" "postgres_service" {
  count = var.services.postgres.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "postgres"
      namespace = "default"
      labels = {
        app = "postgres"
      }
    }
    spec = {
      type = "ClusterIP"
      selector = {
        app = "postgres"
      }
      ports = [
        {
          port = 5432
          targetPort = 5432
          name = "postgres"
        }
      ]
    }
  })
}

# PostgreSQL HPA
resource "kubectl_manifest" "postgres_hpa" {
  count = var.services.postgres.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "postgres-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "postgres"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# Redis ConfigMap
resource "kubectl_manifest" "redis_configmap" {
  count = var.services.redis.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "redis-config"
      namespace = "default"
    }
    data = {
      "redis.conf" = join("\n", [
        "maxmemory ${var.services.redis.env.REDIS_MAXMEMORY}",
        "maxmemory-policy ${var.services.redis.env.REDIS_MAXMEMORY_POLICY}",
        "appendonly ${var.services.redis.env.REDIS_APPENDONLY}",
        "save 900 1",
        "save 300 10",
        "save 60 10000"
      ])
    }
  })
}

# Redis Deployment
resource "kubectl_manifest" "redis_deployment" {
  count = var.services.redis.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "redis"
      namespace = "default"
      labels = {
        app = "redis"
      }
    }
    spec = {
      replicas = var.services.redis.replicas
      selector = {
        matchLabels = {
          app = "redis"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "redis"
          }
        }
        spec = {
          containers = [
            {
              name = "redis"
              image = "redis:7.0-alpine"
              ports = [
                {
                  containerPort = 6379
                  name = "redis"
                }
              ]
              command = ["redis-server", "/etc/redis/redis.conf"]
              env = [
                {
                  name = "REDIS_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "redis-secret"
                      key = "password"
                    }
                  }
                }
              ]
              resources = var.services.redis.resources
              volumeMounts = [
                {
                  name = "redis-config"
                  mountPath = "/etc/redis"
                },
                {
                  name = "redis-data"
                  mountPath = "/data"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "redis-config"
              configMap = {
                name = "redis-config"
              }
            },
            {
              name = "redis-data"
              emptyDir = {}
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.redis_configmap]
}

# Redis Service
resource "kubectl_manifest" "redis_service" {
  count = var.services.redis.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "redis"
      namespace = "default"
      labels = {
        app = "redis"
      }
    }
    spec = {
      type = "ClusterIP"
      selector = {
        app = "redis"
      }
      ports = [
        {
          port = 6379
          targetPort = 6379
          name = "redis"
        }
      ]
    }
  })
}

# Redis HPA
resource "kubectl_manifest" "redis_hpa" {
  count = var.services.redis.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "redis-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "redis"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# Weaviate Deployment
resource "kubectl_manifest" "weaviate_deployment" {
  count = var.services.weaviate.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
      name = "weaviate"
      namespace = "default"
      labels = {
        app = "weaviate"
      }
    }
    spec = {
      replicas = var.services.weaviate.replicas
      selector = {
        matchLabels = {
          app = "weaviate"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "weaviate"
          }
        }
        spec = {
          containers = [
            {
              name = "weaviate"
              image = "semitechnologies/weaviate:1.21.2"
              ports = [
                {
                  containerPort = 8080
                  name = "http"
                },
                {
                  containerPort = 50051
                  name = "grpc"
                }
              ]
              env = [
                for key, value in var.services.weaviate.env : {
                  name = key
                  value = tostring(value)
                }
              ]
              resources = var.services.weaviate.resources
              volumeMounts = [
                {
                  name = "weaviate-data"
                  mountPath = "/var/lib/weaviate"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "weaviate-data"
              emptyDir = {}
            }
          ]
        }
      }
    }
  })
}

# Weaviate Service
resource "kubectl_manifest" "weaviate_service" {
  count = var.services.weaviate.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "weaviate"
      namespace = "default"
      labels = {
        app = "weaviate"
      }
    }
    spec = {
      type = "ClusterIP"
      selector = {
        app = "weaviate"
      }
      ports = [
        {
          port = 80
          targetPort = 8080
          name = "http"
        },
        {
          port = 50051
          targetPort = 50051
          name = "grpc"
        }
      ]
    }
  })
}

# Keycloak Deployment
resource "kubectl_manifest" "keycloak_deployment" {
  count = var.services.keycloak.enabled ? 1 : 0

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
              ports = [
                {
                  containerPort = 8080
                  name = "http"
                },
                {
                  containerPort = 9000
                  name = "management"
                }
              ]
              env = [
                {
                  name = "KEYCLOAK_ADMIN"
                  valueFrom = {
                    secretKeyRef = {
                      name = "keycloak-secret"
                      key = "admin_username"
                    }
                  }
                },
                {
                  name = "KEYCLOAK_ADMIN_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "keycloak-secret"
                      key = "admin_password"
                    }
                  }
                },
                {
                  name = "KC_DB_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = "postgres-secret"
                      key = "username"
                    }
                  }
                },
                {
                  name = "KC_DB_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "postgres-secret"
                      key = "password"
                    }
                  }
                },
                {
                  name = "KC_DB"
                  value = var.services.keycloak.env.KC_DB
                },
                {
                  name = "KC_DB_URL"
                  value = "jdbc:postgresql://postgres:5432/${var.services.postgres.env.POSTGRES_DB}"
                },
                {
                  name = "KC_HOSTNAME"
                  value = var.services.keycloak.env.KC_HOSTNAME
                },
                {
                  name = "KC_HTTP_ENABLED"
                  value = var.services.keycloak.env.KC_HTTP_ENABLED
                },
                {
                  name = "KC_PROXY"
                  value = var.services.keycloak.env.KC_PROXY
                }
              ]
              resources = var.services.keycloak.resources
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.postgres_deployment]
}

# Keycloak Service
resource "kubectl_manifest" "keycloak_service" {
  count = var.services.keycloak.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "keycloak"
      namespace = "default"
      labels = {
        app = "keycloak"
      }
    }
    spec = {
      type = "ClusterIP"
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
    }
  })
}

# Keycloak HPA
resource "kubectl_manifest" "keycloak_hpa" {
  count = var.services.keycloak.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "keycloak-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "keycloak"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# Backend ConfigMap - Now dynamically builds URLs from domain config
resource "kubectl_manifest" "backend_configmap" {
  count = var.services.backend.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "backend-config"
      namespace = "default"
    }
    data = merge(
      var.services.backend.env,
      {
        MONGODB_URL = "mongodb://mongodb-headless:27017/${var.services.mongodb.env.MONGO_INITDB_DATABASE}"
        POSTGRES_URL = "postgresql://postgres:5432/${var.services.postgres.env.POSTGRES_DB}"
        REDIS_URL = "redis://redis:6379"
        WEAVIATE_URL = var.domains.weaviate
        KEYCLOAK_URL = var.domains.keycloak
        FRONTEND_URL = var.domains.frontend
        BACKEND_URL = var.domains.backend
        CORS_ALLOWED_ORIGINS = var.domains.frontend
        CELERY_BROKER_URL = "redis://redis:6379/0"
        CELERY_RESULT_BACKEND = "redis://redis:6379/0"
      }
    )
  })
}

# Backend Deployment
resource "kubectl_manifest" "backend_deployment" {
  count = var.services.backend.enabled ? 1 : 0

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
              image = "your-backend-image:latest"
              ports = [
                {
                  containerPort = 8000
                  name = "http"
                }
              ]
              envFrom = [
                {
                  configMapRef = {
                    name = "backend-config"
                  }
                },
                {
                  secretRef = {
                    name = "backend-secrets"
                  }
                }
              ]
              resources = var.services.backend.resources
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.backend_configmap]
}

# Backend Service
resource "kubectl_manifest" "backend_service" {
  count = var.services.backend.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "backend-app"
      namespace = "default"
      labels = {
        app = "backend-app"
      }
    }
    spec = {
      type = "ClusterIP"
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
    }
  })
}

# Backend HPA
resource "kubectl_manifest" "backend_hpa" {
  count = var.services.backend.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "backend-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "backend-app"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# Frontend ConfigMap - Now dynamically builds URLs from domain config
resource "kubectl_manifest" "frontend_configmap" {
  count = var.services.frontend.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "frontend-config"
      namespace = "default"
    }
    data = merge(
      var.services.frontend.env,
      {
        NEXT_PUBLIC_API_URL = var.domains.backend
        NEXT_PUBLIC_FRONTEND_URL = var.domains.frontend
        NEXT_PUBLIC_KEYCLOAK_URL = var.domains.keycloak
      }
    )
  })
}

# Frontend Deployment
resource "kubectl_manifest" "frontend_deployment" {
  count = var.services.frontend.enabled ? 1 : 0

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
              image = "your-frontend-image:latest"
              ports = [
                {
                  containerPort = 5173
                  name = "http"
                }
              ]
              envFrom = [
                {
                  configMapRef = {
                    name = "frontend-config"
                  }
                },
                {
                  secretRef = {
                    name = "frontend-secrets"
                  }
                }
              ]
              resources = var.services.frontend.resources
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.frontend_configmap]
}

# Frontend Service
resource "kubectl_manifest" "frontend_service" {
  count = var.services.frontend.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "frontend-app"
      namespace = "default"
      labels = {
        app = "frontend-app"
      }
    }
    spec = {
      type = "ClusterIP"
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
    }
  })
}

# Frontend HPA
resource "kubectl_manifest" "frontend_hpa" {
  count = var.services.frontend.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "frontend-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "frontend-app"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
    }
  })
}

# Celery ConfigMap - Now dynamically builds URLs from domain config
resource "kubectl_manifest" "celery_configmap" {
  count = var.services.celery.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "celery-config"
      namespace = "default"
    }
    data = merge(
      var.services.celery.env,
      {
        MONGODB_URL = "mongodb://mongodb-headless:27017/${var.services.mongodb.env.MONGO_INITDB_DATABASE}"
        REDIS_URL = "redis://redis:6379"
        WEAVIATE_URL = var.domains.weaviate
        CELERY_BROKER_URL = "redis://redis:6379/0"
        CELERY_RESULT_BACKEND = "redis://redis:6379/0"
      }
    )
  })
}

# Celery Deployment
resource "kubectl_manifest" "celery_deployment" {
  count = var.services.celery.enabled ? 1 : 0

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
              name = "celery"
              image = "maniniabhi/celery-worker:latest"
              envFrom = [
                {
                  configMapRef = {
                    name = "celery-config"
                  }
                },
                {
                  secretRef = {
                    name = "celery-secrets"
                  }
                }
              ]
              resources = var.services.celery.resources
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.celery_configmap]
}

# Celery Service
resource "kubectl_manifest" "celery_service" {
  count = contains(keys(var.services), "celery") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "celery-worker"
      namespace = "default"
    }
    spec = {
      selector = {
        app = "celery-worker"
      }
      ports = [
        {
          port = 80
          targetPort = 8000
          protocol = "TCP"
        }
      ]
      type = "ClusterIP"
    }
  })
}

# Celery HPA
resource "kubectl_manifest" "celery_hpa" {
  count = var.services.celery.enabled && var.hpa_config.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "celery-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "celery-worker"
      }
      minReplicas = var.hpa_config.min_replicas
      maxReplicas = var.hpa_config.max_replicas
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = var.hpa_config.target_cpu_utilization
            }
          }
        }
      ]
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
          annotations = var.cloud_provider == "aws" ? {
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

# Main Ingress
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
          host = replace(var.domains.backend, "https://", "")
          http = {
            paths = [
              {
                path = "/(.*)"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "backend-app"
                    port = {
                      number = 8000
                    }
                  }
                }
              }
            ]
          }
        },
        {
          host = replace(var.domains.frontend, "https://", "")
          http = {
            paths = [
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
        },
        {
          host = replace(var.domains.keycloak, "https://", "")
          http = {
            paths = [
              {
                path = "/(.*)"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "keycloak"
                    port = {
                      number = 8080
                    }
                  }
                }
              }
            ]
          }
        },
        {
          host = replace(var.domains.weaviate, "https://", "")
          http = {
            paths = [
              {
                path = "/(.*)"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "weaviate"
                    port = {
                      number = 80
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
