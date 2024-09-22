# Deploying Leyline to a Kubernetes Cluster Using Helm

## Prerequisites

Before you can deploy the application to your Kubernetes cluster, make sure you have the following prerequisites:

1. **Kubernetes Cluster**
   Ensure you have a Kubernetes cluster running. You can use any of the following:

   - Minikube (local Kubernetes cluster)
   - Kind (Kubernetes in Docker)
   - Cloud Providers (e.g., AWS EKS, Google GKE, Azure AKS)

2. **kubectl**
   kubectl is the Kubernetes command-line tool. Install it following [these instructions](https://kubernetes.io/docs/tasks/tools/).

3. **Helm**
   Ensure Helm is installed on your local machine. You can install it by following [Helm's installation guide](https://helm.sh/docs/intro/install/).

4. **Docker Hub Account**
   You need access to a Docker Hub account to pull your Docker image. Ensure you have:

   - Docker Hub username
   - Docker Hub password or access token

5. **Access to Your Docker Image**
   Ensure that your Docker image is available in Docker Hub. The image should have been pushed using your CI/CD pipeline and should be versioned based on the Git commit SHA or tagged as latest.

6. **Helm Chart**
   Ensure your Helm chart is available in the repository, typically located in the `helm-chart` directory.

## Environmental Variables

Before deploying the application, make sure you configure the following environment variables:

| Variable      | Description                                            | Example                                       |
| ------------- | ------------------------------------------------------ | --------------------------------------------- |
| DOCKER_REPO   | Docker Hub repository where your image is stored       | `myusername/myapp`                            |
| IMAGE_TAG     | The tag of the image you want to deploy                | `latest` or Git commit SHA (e.g., `c11c540`)  |
| DATABASE_URL  | URL for connecting to your PostgreSQL database         | `postgresql://user:password@db:5432/database` |
| REDIS_URL     | URL for connecting to your Redis instance              | `redis://redis:6379`                          |
| K8S_NAMESPACE | Kubernetes namespace where the application will deploy | `default`                                     |
| APP_PORT      | The port your application will run on (if applicable)  | `3000`                                        |

Note: Adjust these variables according to your environment.

## Deployment Steps

### 1. Set Up Helm on the Kubernetes Cluster

If you haven't done so already, initialize Helm on your Kubernetes cluster using the following command:

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

### 2. Create a Kubernetes Namespace (Optional)

If you want to deploy your application into a specific namespace, create it using:

```bash
kubectl create namespace <namespace-name>
```

Replace `<namespace-name>` with your desired namespace (e.g., `my-app-namespace`).

### 3. Deploy the Application Using Helm

1. Change directory to where your Helm chart is located:

   ```bash
   cd helm-chart
   ```

2. Deploy the application with the necessary environment variables:

   ```bash
   helm upgrade --install myapp . \
     --namespace <namespace> \
     --set image.repository=$DOCKER_REPO \
     --set image.tag=$IMAGE_TAG \
     --set env.DATABASE_URL=$DATABASE_URL \
     --set env.REDIS_URL=$REDIS_URL \
     --set service.port=$APP_PORT
   ```

   Replace:

   - `<namespace>` with the Kubernetes namespace where you want to deploy the application.
   - `myapp` with your desired release name for Helm.

   Example Command:

   ```bash
   helm upgrade --install myapp . \
     --namespace default \
     --set image.repository=myusername/myapp \
     --set image.tag=latest \
     --set env.DATABASE_URL=postgresql://leyline_user:password@db:5432/leyline_db \
     --set env.REDIS_URL=redis://redis:6379 \
     --set service.port=3000
   ```

### 4. Verify the Deployment

Check if the application is running correctly:

```bash
kubectl get pods -n <namespace>
```

Replace `<namespace>` with the namespace you used.

You can also check the services to get the external IP or ClusterIP:

```bash
kubectl get services -n <namespace>
```

### 5. Accessing the Application

Once the deployment is successful, access the application using the service's IP or DNS name. If using Minikube, you can run:

```bash
minikube service myapp-service --namespace <namespace>
```

For cloud providers, use the External IP from `kubectl get services`.

## Updating the Application

If you make changes to your Docker image or Helm chart, simply update the deployment by running the Helm upgrade command:

```bash
helm upgrade myapp . --namespace <namespace> --set image.tag=<new-tag>
```

Replace `<new-tag>` with your new image tag.

## Uninstalling the Application

To uninstall the application, run:

```bash
helm uninstall myapp --namespace <namespace>
```

Replace `<namespace>` with the Kubernetes namespace.

This documentation provides a comprehensive guide to deploying your application to a Kubernetes cluster using Helm. Ensure you adjust environment variables and commands as needed for your setup.
