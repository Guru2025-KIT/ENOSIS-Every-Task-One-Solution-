# Base image with Python pre-installed
FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (separate layer) so Docker caches this step
# and doesn't reinstall everything just because we changed one .py file.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the actual application code
COPY ./app ./app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
