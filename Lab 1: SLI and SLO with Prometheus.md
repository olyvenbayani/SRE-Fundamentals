Lab 1: SLI/SLOs with Prometheus

Welcome to Lab 1 of the SRE Workshop! This hands-on activity introduces you to Service Level Indicators (SLIs) and Service Level Objectives (SLOs) using a simple, fun web application monitored by Prometheus. We'll build a Python app that tells jokes, containerize it with Docker, set up monitoring, define SLIs and SLOs, and validate them with simulated traffic.

This guide is designed for beginners. Each step includes explanations, why we're doing it, and troubleshooting tips. We'll assume you've completed Lab 0 (setup with Docker, Docker Compose, etc.). If not, go back and install those tools first.

**Time Estimate:** 45-60 minutes.  
**Goals:**  
- Understand SLIs (measurable aspects of service quality, like latency).  
- Set SLOs (targets for SLIs, like "99% of requests under 200ms").  
- Use Prometheus to monitor and query metrics.  
- Simulate real-world scenarios to check if SLOs are met.

## Step 1: Create the Lab Directory
**Why?** We need an organized folder to hold all files for the app, configs, and docs. This keeps everything tidy.

1. Open your terminal (Command Prompt on Windows, Terminal on macOS/Linux).
2. Create a new directory:  
   ```
   mkdir sre-lab1
   cd sre-lab1
   ```
3. Inside this directory, we'll create the files below. Use a text editor like VS Code to make them.

## Step 2: Build the Sample App
**Why?** This is a simple Python web app using Flask. It has two endpoints: `/success` (works fine) and `/failure` (simulates errors). We've added funny SRE-themed jokes to make testing enjoyable. The app exposes metrics for Prometheus to monitor requests, errors, and latency.

Create these files in your `sre-lab1` directory:

### File: `app.py` (The Main App Code)
This script runs the web server. It includes random delays to simulate real latency and exports metrics.

```python
from flask import Flask, jsonify
import time
import random
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
metrics = PrometheusMetrics(app)

# Export default metrics
metrics.info('app_info', 'Application info', version='1.0.0')

# List of funny jokes/puns (SRE-themed where possible)
jokes = [
    "Why did the SRE go to therapy? Too many incidents!",
    "Error budgets are like diets: easy to set, hard to stick to.",
    "Why don't programmers like nature? Too many bugs.",
    "SLOs: Because 'best effort' isn't measurable.",
    "Why was the computer cold? It left its Windows open!",
    "Failure is not an option—it's a feature in beta.",
    "Why did the database administrator leave his wife? She had one too many relationships.",
    "Alert: Your coffee is low— that's the real outage.",
    "Why do SREs make great musicians? They handle scales well.",
    "404: Joke not found. Wait, that's not funny."
]

@app.route('/success')
def success():
    # Simulate variable latency: 50-150ms
    delay = random.uniform(0.05, 0.15)
    time.sleep(delay)
    joke = random.choice(jokes)
    return jsonify(message=f"Success! Here's a joke: {joke}"), 200

@app.route('/failure')
def failure():
    # Simulate error with higher latency: 200-500ms
    delay = random.uniform(0.2, 0.5)
    time.sleep(delay)
    joke = random.choice(jokes)
    return jsonify(message=f"Oops, failure! But hey: {joke}"), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000)
```

**Explanation:**  
- `Flask` creates the web app.  
- `prometheus_flask_exporter` adds monitoring (e.g., tracks request counts and times).  
- Endpoints return JSON with jokes. Success is fast and reliable; failure is slow and errors out.  
- Port 3000 avoids common conflicts (like default Flask port 5000).

### File: `requirements.txt` (Dependencies)
Lists Python packages needed.

```
flask==3.0.3
prometheus-flask-exporter==0.23.1
```

**Explanation:** Docker will install these when building the container. No need to install them locally.

### File: `Dockerfile` (Build Instructions for the App Container)
Defines how to package the app into a Docker image.

```
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 3000

CMD ["python", "app.py"]
```

**Explanation:**  
- Starts from a lightweight Python image.  
- Copies files and installs dependencies.  
- Exposes port 3000 for access.

### File: `docker-compose.yml` (Run Multiple Containers)
Sets up the app and Prometheus together.

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    container_name: sample-app

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    container_name: prometheus
    depends_on:
      - app
```

**Explanation:**  
- `app`: Builds from your Dockerfile.  
- `prometheus`: Uses a pre-built image, mounts a config file.  
- Ports: App on 3000 (local and container), Prometheus UI on 9090.  
- No `version` line to avoid warnings.

### File: `prometheus.yml` (Prometheus Config)
Tells Prometheus what to monitor.

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'sample-app'
    static_configs:
      - targets: ['app:3000']
```

**Explanation:**  
- Scrapes metrics from the app every 15 seconds.  
- Targets the app container at its internal port 3000.

## Step 3: Deploy the App
**Why?** This starts the containers so you can interact with the app and monitor it.

1. In your terminal (in the `sre-lab1` directory):  
   ```
   docker-compose up -d --build
   ```
   - `--build` builds the app image.  
   - `-d` runs in the background.

2. Wait a few seconds, then check if it's running:  
   ```
   docker ps
   ```
   - You should see `sample-app` and `prometheus`.
  
<img width="1241" height="650" alt="Lab1-01" src="https://github.com/user-attachments/assets/431887ee-1a0d-4d82-a9f0-bd0065b44f95" />


**Troubleshooting:**  
- If it fails (e.g., port conflict), run `docker-compose down`, then try again. Or change the host port in `docker-compose.yml` (e.g., "3001:3000").  
- View logs: `docker logs sample-app`.

## Step 4: Verify the App
**Why?** Ensures everything works before monitoring.

1. Open a browser:  
   - http://localhost:3000/success – See a success message with a joke (HTTP 200).  
   - http://localhost:3000/failure – See a failure message with a joke (HTTP 500).
  
<img width="1639" height="538" alt="Lab1-02" src="https://github.com/user-attachments/assets/fadb5413-6b1d-44c6-94dd-baa5828dde14" />


2. Check metrics: http://localhost:3000/metrics – Raw data for Prometheus.  
<img width="1160" height="770" alt="Lab1-05" src="https://github.com/user-attachments/assets/3c0c263e-6089-4a44-ae90-8ba6d85cb569" />



3. Open Prometheus UI: http://localhost:9090  
   - In the "Expression" box, query `http_server_requests_total` and click "Execute". You should see request counts.
  
<img width="3342" height="842" alt="Lab1-03" src="https://github.com/user-attachments/assets/2b7cdde7-4592-4d54-b84f-bc0293d7f61c" />


**Explanation:** These tests confirm the app responds and exposes metrics.

**Explore More Queries:**
To get comfortable with Prometheus, try these additional queries in the Expression box. Click "Execute" after each one, and observe the results in the table or graph view (switch tabs above the results). This helps you understand the metrics before defining SLIs:

- flask_http_server_requests_total{status="200"}: Counts only successful requests (HTTP 200).

- http_server_requests_total{status="500"}: Counts error requests (HTTP 500).

- rate(http_server_requests_total[5m]): Shows the rate of requests per second over the last 5 minutes.

- histogram_quantile(0.50, sum(rate(http_server_requests_seconds_bucket[5m])) by (le)): Median (50th percentile) latency—how long half of requests take.

- histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket[5m])) by (le)): 99th percentile latency—how long the slowest 1% of requests take.

- up: Checks if the app is up (1 = up, 0 = down).

Why explore? These build on the basics and prepare you for Step 5. Experiment by making more requests to the app (e.g., reload the browser pages) and see how numbers change. If a query returns "No data," generate traffic by visiting the endpoints multiple times.

Explanation: These tests confirm the app responds and exposes metrics.

## Step 5: Define SLIs
**Why?** SLIs are the "what" we measure (e.g., error rate). We'll document them.

Create `slis.md`:

```
# SLIs for Sample API

1. Availability: Percentage of requests that return HTTP 200.
   - Why? Measures if the service is up and working.
   - Formula: (successful_requests / total_requests) * 100
   - Prometheus Query: sum(rate(flask_http_request_total{status="200"}[5m])) / sum(rate(flask_http_request_total[5m])) * 100

2. Latency: 99th percentile of request times.
   - Why? Shows how fast the service is for most users.
   - Formula: 99% of requests under a threshold (e.g., 200ms).
   - Prometheus Query: histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket[5m])) by (le))
```

**Explanation:** Use these queries in Prometheus to see real values. Adjust based on your needs.

## Step 6: Set SLOs
**Why?** SLOs are targets (e.g., "99.9% availability"). They make SLIs actionable.

Create `slos.yaml`:

```yaml
service: sample-api
slos:
  - name: availability
    objective: 99.9%
    window: 28 days  # Use 5 minutes for lab testing
    sli: proportion of HTTP 200 responses
    justification: Users expect the service to be reliable.

  - name: latency
    objective: 99% of requests < 200ms
    window: 28 days
    sli: 99th percentile request duration
    justification: Fast responses keep users happy.
```

**Explanation:** In production, windows are long; here, short for quick tests.

## Step 7: Simulate Traffic and Validate
**Why?** Real traffic generates data to check if SLOs hold.

Create `simulate_traffic.sh`:

```bash
#!/bin/bash
ab -n 800 -c 10 http://localhost:3000/success
ab -n 200 -c 10 http://localhost:3000/failure
```

1. Make it runnable: `chmod +x simulate_traffic.sh`  
2. Run: `./simulate_traffic.sh`


<img width="1160" height="770" alt="Lab1-05" src="https://github.com/user-attachments/assets/04c36c1a-7b28-41b8-9741-51faa9a4d7f1" />


3. In Prometheus UI: Re-run SLI queries.  
   - Availability: Should be ~80% (due to failures). Is it above 99.9%? (No—discuss why and adjust script for passing tests.)
   
   Run prom query:
```
sum(rate(flask_http_request_total{status="200"}[5m])) /
sum(rate(flask_http_request_total[5m]))
```

**How to check it:**

Run the query
If it's ≥ 0.999 → SLO met
If it's < 0.999 → SLO violated

<img width="3310" height="1470" alt="Lab1-07" src="https://github.com/user-attachments/assets/bc09ad45-d8fe-467f-af0c-87e86d18a410" />

     
   - Latency: Check if most are under 200ms.
```
histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket[5m])) by (le))
```


**How to check it:**

Run the query
Look at the output
If value is < 0.2 seconds → SLO met
If value is ≥ 0.2 seconds → SLO violated

**Explanation:** `ab` sends requests. Adjust numbers for different scenarios.

## Step 8: Cleanup and Reflect
1. Stop: `docker-compose down`  
2. Think: How would you change SLOs for a real app? What if latency spikes?

**Troubleshooting Tips for Beginners:**  
- Errors? Check logs with `docker logs <container>`.  
- No metrics? Ensure the app is hit a few times.  
- Stuck? Search "Docker [error message]" online.

You've completed Lab 1! If issues arise, ask your instructor. Ready for Lab 2?
