terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

locals {
  pod_labels = {
    app = var.name
  }
}

# Create a Kubernetes Deployment to run an app
# Create a simple Kubernetes Deployment to run an app
resource "kubernetes_deployment" "app" {
  metadata {
    name = var.name
  }

  # kubernetes_deployment configuration goes into the spec block
  spec {
    # Specify number of replicas to create
    replicas = var.replicas

    # template of pods to deploy
    template {

      # Labels are intended to be used to specify identifying attributes of objects that are meaningful and relevant to users
      metadata {
        labels = local.pod_labels
      }

      # Pod configurations
      spec {
        # You can define one or more containers to run in the pod
        container {
          name  = var.name
          image = var.image

          port {
            container_port = var.container_port
          }

          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }

    # What deployment to target
    selector {
      match_labels = local.pod_labels
    }
  }
}

# Create a simple Kubernetes Service to spin up a load balancer in front
# of the app in the Kubernetes Deployment.
resource "kubernetes_service" "app" {
  metadata {
    name = var.name
  }

  spec {
    type = "LoadBalancer"
    port {
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }
    selector = local.pod_labels
  }
}
