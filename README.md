# nginx-tlscert
This project shows how to deploy a secure Nginx reverse proxy with a Golang backend on Kubernetes. It enforces HTTPS-only traffic, runs containers as non-root, uses ConfigMaps for routing, Secrets for TLS, and multi-stage Alpine builds to reduce the attack surface.
