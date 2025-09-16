# MongoDB Secret
resource "kubectl_manifest" "mongodb_secret" {
  count = contains(keys(var.services), "mongodb") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
      name = "mongodb-secret"
      namespace = "default"
    }
    type = "Opaque"
    data = {
      username = base64encode(var.services.mongodb.credentials.username)
      password = base64encode(var.services.mongodb.credentials.password)
    }
  })
}

# MongoDB StatefulSet
resource "kubectl_manifest" "mongodb_statefulset" {
  count = contains(keys(var.services), "mongodb") ? 1 : 0

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
  count = contains(keys(var.services), "mongodb") ? 1 : 0

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
  count = contains(keys(var.services), "mongodb") ? 1 : 0

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
      minReplicas = var.services.mongodb.replicas
      maxReplicas = var.services.mongodb.replicas * 2
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# PostgreSQL Secret
resource "kubectl_manifest" "postgres_secret" {
  count = contains(keys(var.services), "postgres") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
      name = "postgres-secret"
      namespace = "default"
      labels = {
        app = "postgres"
      }
    }
    type = "Opaque"
    data = {
      POSTGRES_DB = base64encode(var.services.postgres.credentials.database)
      POSTGRES_USER = base64encode(var.services.postgres.credentials.username)
      POSTGRES_PASSWORD = base64encode(var.services.postgres.credentials.password)
    }
  })
}

# PostgreSQL Deployment
resource "kubectl_manifest" "postgres_deployment" {
  count = contains(keys(var.services), "postgres") ? 1 : 0

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
              envFrom = [
                {
                  secretRef = {
                    name = "postgres-secret"
                  }
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
  count = contains(keys(var.services), "postgres") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "postgres"
      namespace = "default"
    }
    spec = {
      type = "NodePort"
      selector = {
        app = "postgres"
      }
      ports = [
        {
          port = 5432
          targetPort = 5432
          nodePort = 30100
          protocol = "TCP"
        }
      ]
    }
  })
}

# PostgreSQL HPA
resource "kubectl_manifest" "postgres_hpa" {
  count = contains(keys(var.services), "postgres") ? 1 : 0

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
      minReplicas = var.services.postgres.replicas
      maxReplicas = var.services.postgres.replicas * 2
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# Redis ConfigMap
resource "kubectl_manifest" "redis_configmap" {
  count = contains(keys(var.services), "redis") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "redis-config"
      namespace = "default"
    }
    data = {
      "redis.conf" = join("\n", [
        for key, value in var.services.redis.env : "${key} ${value}"
      ])
    }
  })
}

# Redis Deployment
resource "kubectl_manifest" "redis_deployment" {
  count = contains(keys(var.services), "redis") ? 1 : 0

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
              image = "redis:7.2-alpine"
              ports = [
                {
                  containerPort = 6379
                  name = "redis"
                }
              ]
              command = ["redis-server", "/etc/redis/redis.conf"]
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
  count = contains(keys(var.services), "redis") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "redis-service"
      namespace = "default"
    }
    spec = {
      type = "LoadBalancer"
      selector = {
        app = "redis"
      }
      ports = [
        {
          port = 6379
          targetPort = 6379
          protocol = "TCP"
        }
      ]
    }
  })
}

# Redis HPA
resource "kubectl_manifest" "redis_hpa" {
  count = contains(keys(var.services), "redis") ? 1 : 0

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
      minReplicas = var.services.redis.replicas
      maxReplicas = var.services.redis.replicas * 3
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# Weaviate Deployment
resource "kubectl_manifest" "weaviate_deployment" {
  count = contains(keys(var.services), "weaviate") ? 1 : 0

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
              image = "semitechnologies/weaviate:1.22.4"
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
  count = contains(keys(var.services), "weaviate") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "weaviate"
      namespace = "default"
    }
    spec = {
      type = "LoadBalancer"
      selector = {
        app = "weaviate"
      }
      ports = [
        {
          port = 80
          targetPort = 8080
          protocol = "TCP"
          name = "http"
        },
        {
          port = 50051
          targetPort = 50051
          protocol = "TCP"
          name = "grpc"
        }
      ]
    }
  })
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
              env = concat([
                {
                  name = "KEYCLOAK_ADMIN"
                  value = var.services.keycloak.credentials.username
                },
                {
                  name = "KEYCLOAK_ADMIN_PASSWORD"
                  value = var.services.keycloak.credentials.password
                },
                {
                  name = "KC_DB"
                  value = "postgres"
                },
                {
                  name = "KC_DB_URL"
                  value = "jdbc:postgresql://postgres:5432/${var.services.postgres.credentials.database}"
                },
                {
                  name = "KC_DB_USERNAME"
                  value = var.services.postgres.credentials.username
                },
                {
                  name = "KC_DB_PASSWORD"
                  value = var.services.postgres.credentials.password
                }
              ], [
                for key, value in var.services.keycloak.env : {
                  name = key
                  value = tostring(value)
                }
              ])
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
        },
        {
          port = 9000
          targetPort = 9000
          name = "management"
        }
      ]
      type = "ClusterIP"
    }
  })
}

# Keycloak HPA
resource "kubectl_manifest" "keycloak_hpa" {
  count = contains(keys(var.services), "keycloak") ? 1 : 0

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
      minReplicas = var.services.keycloak.replicas
      maxReplicas = var.services.keycloak.replicas * 2
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# Backend ConfigMap
resource "kubectl_manifest" "backend_configmap" {
  count = contains(keys(var.services), "backend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "backend-app-config"
      namespace = "default"
    }
    data = merge(var.services.backend.env, {
      MONGO_URI = "mongodb://${var.services.mongodb.credentials.username}:${var.services.mongodb.credentials.password}@mongodb-0.mongodb-headless.default.svc.cluster.local:27017,mongodb-1.mongodb-headless.default.svc.cluster.local:27017/?replicaSet=rs0"
      REDIS_URL = "redis://redis-service.default.svc.cluster.local:6379"
      WEAVIATE_URI = "http://weaviate.default.svc.cluster.local"
      KEYCLOAK_BASE_URL = "http://keycloak:8080/beta"
      FRONTEND_URL = var.domains.frontend
      BACKEND_URL = var.domains.backend
    })
  })
}

# Backend Deployment
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
              name = "backend-app"
              image = "590184047163.dkr.ecr.ap-south-1.amazonaws.com/101genai/kubernetes:latest"
              ports = [
                {
                  containerPort = 8000
                  name = "http"
                }
              ]
              envFrom = [
                {
                  configMapRef = {
                    name = "backend-app-config"
                  }
                }
              ]
              env = [
                {
                  name = "MONGODB_USERNAME"
                  valueFrom = {
                    secretKeyRef = {
                      name = "mongodb-secret"
                      key = "username"
                    }
                  }
                },
                {
                  name = "MONGODB_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "mongodb-secret"
                      key = "password"
                    }
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

  depends_on = [kubectl_manifest.backend_configmap, kubectl_manifest.mongodb_secret]
}

# Backend Service
resource "kubectl_manifest" "backend_service" {
  count = contains(keys(var.services), "backend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "backend-app"
      namespace = "default"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/docs"
        "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port" = "8000"
        "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" = "HTTP"
      }
    }
    spec = {
      selector = {
        app = "backend-app"
      }
      ports = [
        {
          protocol = "TCP"
          port = 8000
          targetPort = 8000
        }
      ]
      type = "LoadBalancer"
    }
  })
}

# Backend HPA
resource "kubectl_manifest" "backend_hpa" {
  count = contains(keys(var.services), "backend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "backend-app-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "backend-app"
      }
      minReplicas = var.services.backend.replicas
      maxReplicas = var.services.backend.replicas * 3
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# Frontend ConfigMap
resource "kubectl_manifest" "frontend_configmap" {
  count = contains(keys(var.services), "frontend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "frontend-app-config"
      namespace = "default"
    }
    data = merge(var.services.frontend.env, {
      VITE_API_URL = var.domains.backend
      VITE_KEYCLOAK_URL = var.domains.keycloak
      FRONTEND_URL = var.domains.frontend
    })
  })
}

# Frontend Deployment
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
              name = "frontend-app"
              image = "590184047163.dkr.ecr.ap-south-1.amazonaws.com/101genai/frontend:latest"
              ports = [
                {
                  containerPort = 5173
                  name = "http"
                }
              ]
              envFrom = [
                {
                  configMapRef = {
                    name = "frontend-app-config"
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
  count = contains(keys(var.services), "frontend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "Service"
    metadata = {
      name = "frontend-app"
      namespace = "default"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
      }
    }
    spec = {
      selector = {
        app = "frontend-app"
      }
      ports = [
        {
          protocol = "TCP"
          port = 5173
          targetPort = 5173
        }
      ]
      type = "LoadBalancer"
    }
  })
}

# Frontend HPA
resource "kubectl_manifest" "frontend_hpa" {
  count = contains(keys(var.services), "frontend") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "frontend-app-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "frontend-app"
      }
      minReplicas = var.services.frontend.replicas
      maxReplicas = var.services.frontend.replicas * 3
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
            }
          }
        }
      ]
    }
  })
}

# Celery Deployment
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
              env = concat([
                {
                  name = "CELERY_BROKER_URL"
                  value = "redis://redis-service.default.svc.cluster.local:6379/0"
                },
                {
                  name = "CELERY_RESULT_BACKEND"
                  value = "redis://redis-service.default.svc.cluster.local:6379/0"
                },
                {
                  name = "MONGODB_URL"
                  value = "mongodb://${var.services.mongodb.credentials.username}:${var.services.mongodb.credentials.password}@mongodb-0.mongodb-headless.default.svc.cluster.local:27017/?replicaSet=rs0"
                }
              ], [
                for key, value in var.services.celery.env : {
                  name = key
                  value = tostring(value)
                }
              ])
              resources = var.services.celery.resources
            }
          ]
        }
      }
    }
  })
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
  count = contains(keys(var.services), "celery") ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "autoscaling/v2"
    kind = "HorizontalPodAutoscaler"
    metadata = {
      name = "celery-worker-hpa"
      namespace = "default"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        name = "celery-worker"
      }
      minReplicas = var.services.celery.replicas
      maxReplicas = var.services.celery.replicas * 4
      metrics = [
        {
          type = "Resource"
          resource = {
            name = "cpu"
            target = {
              type = "Utilization"
              averageUtilization = 70
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
