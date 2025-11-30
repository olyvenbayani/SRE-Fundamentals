# Adding Slack and Email Notifications to Alertmanager

*Extension for Lab 3: Monitoring, Logging, and Alerting with the Joke API*

This document extends **Lab 3** by adding **Slack** and **Email** alert notifications to Alertmanager.
Prometheus → Alertmanager → Slack/Email
This makes the lab feel closer to a real SRE alerting pipeline.

---

# Overview

Alertmanager currently uses a **blackhole receiver**, meaning alerts appear only in the UI.
In this guide we will configure:

* **Slack Notifications** (recommended)
* **Email Notifications** (optional, but useful)

You will update `alertmanager.yml` and reload Prometheus.

---

# 1. Slack Alert Notifications

## Step 1: Create a Slack Webhook

1. Go to: [https://api.slack.com/messaging/webhooks](https://api.slack.com/messaging/webhooks)
2. Click **Create a Slack App** → choose workspace.
3. Enable **Incoming Webhooks**.
4. Add a new webhook → choose a Slack channel.
5. Copy the generated URL (looks like):

   ```
   https://hooks.slack.com/services/T0000/B0000/XXXXX
   ```

---

## Step 2: Update `alertmanager.yml`

Replace your current file with this:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: slack_alerts
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h

receivers:

  - name: slack_alerts
    slack_configs:
      - api_url: "https://hooks.slack.com/services/REPLACE_ME"
        channel: "#alerts"
        send_resolved: true
        title: "{{ .CommonAnnotations.summary }}"
        text: |
          *Alert:* {{ .CommonLabels.alertname }}
          *Severity:* {{ .CommonLabels.severity }}
          *Service:* {{ .CommonLabels.service }}
          *Description:* {{ .CommonAnnotations.description }}
          *Status:* {{ .Status }}
```

### Notes

* Replace `REPLACE_ME` with your Slack webhook URL.
* Update `channel:` if needed (ex: `#sre-alerts`).

---

# 2. Email Alert Notifications

(Optional – use only if your group wants email alerts.)

## Step 1: SMTP Credentials Needed

You must have:

* SMTP host (e.g., `smtp.gmail.com`)
* SMTP port (e.g., `587`)
* Username (email)
* Password or App Password (for Gmail use App Password)
* From address
* To address

---

## Step 2: Add Email Receiver

Append this to the receivers list:

```yaml
  - name: email_alerts
    email_configs:
      - to: "you@example.com"
        from: "alertmanager@example.com"
        smarthost: "smtp.gmail.com:587"
        auth_username: "your-email@gmail.com"
        auth_password: "YOUR_APP_PASSWORD"
        send_resolved: true
```

---

## Step 3: Route Alerts to Email (Optional)

Modify route to send *critical* alerts to email:

```yaml
route:
  receiver: slack_alerts
  routes:
    - match:
        severity: critical
      receiver: email_alerts
```

This means:

* Warning alerts → Slack
* Critical alerts → Slack + Email

---

# 3. Reloading Alertmanager & Prometheus

After editing configs:

```bash
docker-compose down
docker-compose up -d
```

Or to avoid restart (Prometheus only):

```bash
curl -X POST http://localhost:9090/-/reload
```

Alertmanager automatically reloads config without restart.

---

# 4. Send a Test Alert

Use your existing simulation script:

```bash
./simulate_traffic.sh
```

Expected:

* HighErrorRate → Slack alert
* ServiceDown (if you stop the app) → Slack + Email

---

# 5. Verifying Delivery

### Slack

View your channel → alert messages should appear within seconds.

### Email

Check inbox → “Alertmanager Notification” or similar.

If email fails, check:

* SMTP port blocked
* Incorrect credentials
* Gmail requires App Password

---

# 6. Sample Slack Output (Preview)

```
Alert: HighErrorRate
Severity: warning
Service: joke-api
Description: Error rate is 42% (threshold: 10%). Check application logs immediately.
Status: firing
```

---

# 7. Full Example `alertmanager.yml` (Final Version)

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: slack_alerts
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  routes:
    - match:
        severity: critical
      receiver: email_alerts

receivers:

  - name: slack_alerts
    slack_configs:
      - api_url: "https://hooks.slack.com/services/REPLACE_ME"
        channel: "#alerts"
        send_resolved: true
        title: "{{ .CommonAnnotations.summary }}"
        text: |
          *Alert:* {{ .CommonLabels.alertname }}
          *Severity:* {{ .CommonLabels.severity }}
          *Service:* {{ .CommonLabels.service }}
          *Description:* {{ .CommonAnnotations.description }}
          *Status:* {{ .Status }}

  - name: email_alerts
    email_configs:
      - to: "you@example.com"
        from: "alertmanager@example.com"
        smarthost: "smtp.gmail.com:587"
        auth_username: "your-email@gmail.com"
        auth_password: "YOUR_APP_PASSWORD"
        send_resolved: true
```

---

#  Done!
