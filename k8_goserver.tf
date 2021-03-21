
resource "kubernetes_namespace" "tf-test" {
  metadata {
    name = "tf-test"
    labels = {
      test = "myGoNamespace"
    }
  }
}

resource "kubernetes_deployment" "go-server" {
  metadata {
    name = "go-server"
    namespace = "tf-test"
    labels = {
      "test" = "myGoServer"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        test = "myGoServer"
      }
    }
    template{
      metadata{
        labels = {
          test = "myGoServer"
        }
      }
      spec{
        volume {
          name = "go-server-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.go-server-storage-claim.metadata.0.name
          }
        }
        container{
          env {
            name= "FILE_STORAGE"
            value = var.file-storage
          } 
          image = "wiikip/go:latest"
          name = "go-server"
          volume_mount {
            mount_path = var.file-storage
            name = "go-server-storage"
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "go-server-service" {
  wait_for_load_balancer = false
  metadata {
    name= "go-server-service"
    namespace = "tf-test"
  }
  spec {
    port{
      port = 80
      target_port = 8080
    }
    selector = {
      test = kubernetes_deployment.go-server.metadata.0.labels.test
    }
    type = "LoadBalancer"
  }
  
}
resource "kubernetes_ingress" "name" {
  metadata {
    name = "go-server-ingress"
    namespace = "tf-test"
  }
  spec {
    rule{
      host = "wiikip.viarezo.fr"
      http{
        path{
          path ="/"
          backend{
            service_name = kubernetes_service.go-server-service.metadata.0.name
            service_port = 80
          }
        }
      }

    }
  } 
}
resource "kubernetes_storage_class" "local-storage" {
  metadata{
    name="local-storage"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "Immediate"
}
resource "kubernetes_persistent_volume_claim" "go-server-storage-claim" {
  metadata {
    name = "go-server-storage-claim"
    namespace = "tf-test"
  }
  spec {
    storage_class_name = kubernetes_storage_class.local-storage.metadata.0.name
    access_modes = [ "ReadWriteOnce" ]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
  
}
resource "kubernetes_persistent_volume" "go-server-storage" {
  metadata {
    name = "go-server-storage"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    volume_mode = "Filesystem"
    access_modes = [ "ReadWriteOnce" ]
    persistent_volume_reclaim_policy = "Delete"
    storage_class_name = kubernetes_storage_class.local-storage.metadata.0.name
    persistent_volume_source {
      local{
        path = var.file-storage
      }
    }
    node_affinity {
      required{
        node_selector_term{
          match_expressions{
            key = "kubernetes.io/hostname"
            operator = "In"
            values = ["wiikip-vm"]
          }
        }
      }
    }

  }
  
}