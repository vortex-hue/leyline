#### Dockerfile
FROM python:3.10-slim

#### Set the working directory in the container
WORKDIR /app

#### Copy the requirements file into the container
COPY requirements.txt .

#### Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

#### Copy the application code into the container
COPY . .

#### Copy wait-for-it.sh into the container
COPY wait-for-it.sh /wait-for-it.sh

#### Make the wait-for-it script executable
RUN chmod +x /wait-for-it.sh

#### Expose port 3000 for the application
EXPOSE 3000

#### Use wait-for-it.sh to wait for the database to be ready before starting the app with access logs enabled
CMD ["./wait-for-it.sh", "db:5432", "--", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3000", "--log-level", "info", "--access-log"]
