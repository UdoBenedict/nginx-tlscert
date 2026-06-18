# K8s Secure Ingress: Nginx Proxy & TLS Management

## Introduction
Managing secure communication and dynamic routing is a foundational skill in Kubernetes. Handling TLS/SSL certificates is a daily task for Kubernetes administrators, and securely mounting them is critical.

This project demonstrates how to deploy a secure, production-ready Nginx reverse proxy that sits in front of a lightweight Golang backend application. To minimize security risks such as privilege escalation, the setup enforces HTTPS-only traffic and ensures both containers operate as non-root users.

It emphasizes decoupling configuration from application code by utilizing ConfigMaps for stateless routing rules and Kubernetes Secrets for dynamically mounting TLS certificates. Additionally, the project uses multi-stage Docker builds on a minimal Alpine Linux image to significantly reduce the overall attack surface.

## Tech Stack
`Golang` - `Docker` - `Kubernetes` - `Nginx` - `OpenSSL`

## Architectural Diagram


## What Does This Project Do?
**Key Capabilities**
- Secure TLS Termination: Nginx (Unprivileged) handles incoming HTTPS traffic securely using certificates mounted dynamically from a Kubernetes Secret.

- Dynamic Configuration: Nginx server blocks and routing rules are injected via a ConfigMap, meaning the Nginx image itself remains stateless and reusable.

- Production-Grade Security: Both the Go backend and the Nginx proxy run as non-root users to mitigate privilege escalation risks.

- Multi-Stage Builds: The backend application is compiled statically and run on a minimal Alpine image to drastically reduce the attack surface.

## Core Components
| Component | Tool/Service | Purpose |
| :--- | :---: | ---: |
| Reverse Proxy | Nginx (Unprivileged) | to inner services. |
| Backend App | Golang | A simple API/Web server that processes the routed requests. |
| Routing Rules | Kubernetes ConfigMap | Stores the nginx.conf file that defines server blocks and proxy pass rules. Mounted as a volume. |
| TLS Certificates | Kubernetes Secret | Stores the self-signed TLS certificate and private key. Mounted securely as a volume within the Nginx pod |

## Deployment Guide
### Step 1: Write a dockerfile of the application. Build and push the image to Docker Hub.
```
$ docker build -t udonwaigwe/nginx-tlscert:v1.0 .

$ docker tag udonwaigwe/nginx-tlscert:v1.0 udonwaigwe/nginx-tlscert:v1.0

$ docker push udonwaigwe/nginx-tlscert:v1.0

#The push refers to repository [docker.io/udonwaigwe/nginx-tlscert]
```

## Step 2: Create ConfigMap for NGINX Config File & Secrets for Certificate and Private Key

To generate a self-signed certificate, I need to first generate a private key, alongside the CSR:

```
# To generate the private key of 2048 bits 
$ openssl genrsa -out tls.key 2048

# To generate a CSR using the private key
$ openssl req -new -key tls.key -out tls.csr

# To generate the certificate using the CSR
$ openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt
```
### ConfigMap
In the configmap manifest, you will observe that:

- NGINX is listening on port 8443 instead of the standard 443. This is because Standard NGINX listens on ports 80/443, which require root access but Unprivileged versions generally listen on port 8080 to bypass the restricted port barrier(less than 1024).

- The location in the container where the certificate and private key is mounted.

- proxy_pass http://backend-service:8080 - Forwards those incoming requests to the internal application server behind the service called backend-service running on port 8080.

- proxy_set_header Host $host; Preserves the original domain name the user typed in their browser, so the backend application knows exactly which website is being requested. 

- proxy_set_header X-Real-IP $remote_addr; Passes the visitor's real IP address to the backend, ensuring the app sees the actual user's location instead of NGINX's internal network IP.

### Secret
The below command outputs a secret.yaml manifest:

```
kubectl create secret tls nginx-secret --key tls.key --cert tls.crt --dry-run=client -o yaml > secret.yaml
```
`tls` flag tells Kubernetes the type of Secret to be created. 
`nginx-secret` flag signifies the Secret name.
`--key` and `--cert` flags take in the private key and certificate.
`--dry-run=client -o yaml` flag tells Kubernetes to format the output as a YAML file rather than applying it to the cluster immediately.

### NGINX DEPLOYMENT

In the nginx deployment manifest:

We use the `nginxinc/nginx-unprivileged:alpine` image. Standard Nginx runs worker processes as a non-root user, but the master process runs as root to bind to port 80/443. The unprivileged image runs everything as a non-root user, defaulting to port 8080 (8443 in our case) internally.

We use Volume Mounts to inject both the `nginx-config` ConfigMap and the `nginx-secret` Secret directly into the container's file system at runtime.

## Step 3: Create Namespace and Deploy Resources


```
$ kubectl create namespace demo

$ kubectl -n demo apply -f secret.yaml

$ kubectl -n demo apply -f configmap.yaml

$ kubectl -n demo apply -f go-deploy-svc.yaml

$ kubectl -n demo apply -f nginx-deploy-svc.yaml

# Confirm the deployment
$ kubectl -n demo get pods,deploy,svc,secret,configmap
```

## Step 4: Test the Deployment

To expose the application to the external world, we run the below command to get the External IP:
```
$ kubectl -n demo get svc

NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
backend-service       ClusterIP      10.107.236.230   <none>        8080/TCP        3m34s
nginx-proxy-service   LoadBalancer   10.109.33.230    <pending>     443:32403/TCP   3m21s
```

The <pending> state is because Kubernetes itself doesn't actually create load balancers. Instead, it sends a request to the infrastructure provider (like AWS, Google Cloud, or your local virtualization tool) to create one. Here, minikube is in use and so I port-forward the Nginx service to test it locally:

```
kubectl port-forward svc/nginx-proxy-service 8443:443
```

- In your browser, visit https://localhost:8443
- or via curl in the terminal to https://localhost:8443
- or opening a tunnel for LoadBalancers using `minikube tunnel` to get an external IP.

## Step 5: Cleanup


```
# Delete the deployments and services
$ kubectl -n demo delete -f deployment.yaml

# Delete the ConfigMap
$ kubectl -n demo delete -f configmap.yaml

# Delete the Secret
$ kubectl -n demo delete -f secret.yaml

# (Optional) Remove local certificate files
$ rm tls.key tls.crt secret.yaml
```

Thank you!
