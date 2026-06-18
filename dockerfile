# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /OneDrive/Documents/K8s/nginx-tlscert

COPY main.go .

# Disable CGO for a statically linked binary (no external C libraries needed)
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o backend main.go

# Stage 2: Run
FROM alpine:3.22.4

# Create a dedicated non-root user and group
# -S creates a system user/group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /OneDrive/Documents/K8s/nginx-tlscert

# Copy only the compiled binary from the builder stage
COPY --from=builder /OneDrive/Documents/K8s/nginx-tlscert .

# Change ownership of the binary to the non-root user
RUN chown -R appuser:appgroup /OneDrive/Documents/K8s/nginx-tlscert

# Enforce running as the non-root user
USER appuser

EXPOSE 8080

CMD ["./backend"]

