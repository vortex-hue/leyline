# Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Copy wait-for-it.sh into the container
COPY wait-for-it.sh /wait-for-it.sh

EXPOSE 3000

# Use wait-for-it.sh to wait for the database to be ready before starting the app
CMD ["./wait-for-it.sh", "db:5432", "--", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3000"]
