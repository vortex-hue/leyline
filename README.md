# LeyLine DNS Service

A highly optimized and efficient FastAPI-based DNS lookup service that provides several endpoints for domain resolution, IP validation, query history, and health checks. This service is designed with scalability, security, and Kubernetes readiness in mind, making it suitable for production environments.

## **Table of Contents**

- [Features](#features)
- [Endpoints](#endpoints)
- [Requirements](#requirements)
- [Running Locally](#running-locally)
- [Docker and Docker Compose](#docker-and-docker-compose)
- [Kubernetes Deployment](#kubernetes-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring with Prometheus](#monitoring-with-prometheus)
- [Database Configuration](#database-configuration)
- [Helm Chart Deployment](#helm-chart-deployment)
- [Project Structure](#project-structure)

---

## **Features**

- Domain lookup with IPv4 resolution
- Validation of IPv4 addresses
- Query logging with a PostgreSQL backend
- Access logs for the API
- Health and metrics endpoints
- Kubernetes readiness
- CI/CD pipeline with GitHub Actions
- Helm chart for easy deployment

## **Endpoints**

| Method | Endpoint             | Description                                             |
| ------ | -------------------- | ------------------------------------------------------- |
| GET    | `/`                  | Returns version, current date, and Kubernetes status    |
| POST   | `/v1/tools/lookup`   | Resolves the IPv4 address of a given domain             |
| GET    | `/v1/tools/validate` | Validates whether a string is an IPv4 address           |
| GET    | `/v1/history`        | Retrieves the latest 20 saved queries from the database |
| GET    | `/health`            | Health check of the service                             |
| GET    | `/metrics`           | Prometheus metrics endpoint                             |

## **Requirements**

- Docker
- Docker Compose
- Kubernetes (optional for local setup)
- Helm (for Kubernetes deployment)
- PostgreSQL (as the database)
- Python 3.9+

## **Running Locally**

### 1. **Clone the Repository**

```bash
git clone https://github.com/your-username/fastapi-dns-service.git
cd fastapi-dns-service
```

### 2. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the Application

Ensure you have a running PostgreSQL instance. You can modify the `DATABASE_URL` environment variable in `config/config.py`.

```bash
uvicorn app.main:app --host 0.0.0.0 --port 3000
```

#### Access the API documentation via:

Swagger: `http://localhost:3000/docs`
Redoc: `http://localhost:3000/redoc`

### Docker and Docker Compose

1. Building the Docker Image
   `docker build -t fastapi-dns-service` .

2. Running with Docker Compose

   `docker-compose up -d --build`

   Access the application via `http://localhost:3000`.

   #### Kubernetes Deployment

3. Prerequisites
   Ensure you have a Kubernetes cluster running (e.g., Minikube, Docker Desktop Kubernetes, or a cloud provider).

   _Install kubectl and helm_.

4. Deploying with Helm
   The Helm chart is located in the helm-chart/ directory.

```bash
cd helm-chart
helm install fastapi-dns-service ./ --namespace my-namespace --create-namespace
```

3.  Accessing the Service in Kubernetes
    After deploying, you can access the service via a Kubernetes LoadBalancer or NodePort. Use `kubectl` to get the service details:

```bash
kubectl get svc -n my-namespace
Kubernetes Manifests
```

NB: If you prefer to use Kubernetes manifests directly, apply them using:

`kubectl apply -f kubernetes-manifests.yaml`

### CI/CD Pipeline

1. GitHub Actions
   The CI/CD pipeline uses GitHub Actions and is configured in _.github/workflows/ci.yml_. The pipeline includes:

- Linting the code using flake8
- Building the Docker image
- Running basic tests

_The pipeline is triggered upon each commit to the repository_.

### Monitoring with Prometheus

The `/metrics` endpoint exposes _Prometheus-compatible_ metrics. To scrape these metrics:

**Deploy Prometheus in your Kubernetes cluster using Helm**:

```bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace

```

Update the Prometheus configuration to scrape metrics from the /metrics endpoint.

### Database Configuration

The application uses PostgreSQL as the database backend. The database connection URL can be set using the DATABASE_URL environment variable in the following format:

```bash
postgresql://username:password@hostname/dbname
```

NB: When running in Kubernetes, ensure the database credentials are stored in Kubernetes secrets and injected into the application.

### Helm Chart Deployment

The Helm chart provided in the helm-chart/ folder helps deploy the LeyLine DNS Service into a Kubernetes cluster efficiently. It handles:

- Deployment
- Service configuration
- Ingress setup (if required)

**Customizing the Helm Chart**
You can modify the `values.yaml` file to customize the deployment, such as setting the environment variables, replicas, resource limits, and database configuration.

**To upgrade the deployment using Helm**:

```bash
helm upgrade fastapi-dns-service ./ --namespace my-namespace
```

### Project Structure

```graphql

leyline-dns-service/
│
├── app/
│ ├── **init**.py
│ ├── main.py # Entry point for FastAPI app
│ ├── config.py # Configuration settings
│ ├── database.py # Database connection setup
│ ├── models.py # SQLAlchemy models
│ ├── schemas.py # Pydantic models
│ ├── routers/
│ │ ├── **init**.py
│ │ ├── tools.py # Endpoints for DNS tools
│ │ ├── metrics.py # Prometheus metrics endpoint
│ │ └── health.py # Health check endpoint
│ └── services/
│ ├── **init**.py
│ └── dns_service.py # Domain resolution service
│
├── Dockerfile # Dockerfile for building the container
├── docker-compose.yml # Docker Compose configuration
├── helm-chart/ # Helm chart for Kubernetes deployment
│ ├── Chart.yaml
│ ├── values.yaml
│ └── templates/
│ ├── deployment.yaml
│ ├── service.yaml
│ └── ingress.yaml
├── requirements.txt # Python dependencies
├── README.md # Documentation
└── .github/
└── workflows/
└── ci.yml # GitHub Actions CI/CD pipeline
```

### Additional Notes

- Graceful Shutdown: The application is configured for graceful shutdowns, ensuring all requests are completed before the service stops.

- Security: Sensitive data like database credentials should always be stored as environment variables or Kubernetes secrets.

- Logging: Logs are configured to be captured and exported to external logging solutions such as ELK, AWS CloudWatch, or Google Cloud Logging when deployed in production environments.

### License

This project is licensed under the MIT License.

```rust
This `README.md` covers everything you need to start, deploy, and manage the FastAPI application in different environments, while highlighting important features, deployment strategies, and integration points for Kubernetes, Docker, and CI/CD. It serves as a comprehensive guide for anyone who wants to understand or deploy your project.
```

# leyline
