# SRE Workshop Case Study  
## Using Google SLI/SLO Framework  
### Activity: Stabilizing the Banking Payments API

---

## Scenario Overview
You are part of the SRE team responsible for the **Payments Processing API** of a major bank.  
You are given **30 days of production metrics** and must define SLIs, propose SLOs, calculate error budgets, and make reliability recommendations using Google’s SRE principles.

---

## Provided Metrics for Analysis

### 1. **Availability (Success / Failure Rates)**
- **Total requests:** 120,000,000  
- **Successful (2xx, 3xx):** 119,400,000  
- **Failed requests:** 600,000  
- **Current availability:** **99.5%**

---

### 2. **Latency Metrics**
| Metric | Value |
|--------|-------|
| p50 latency | 150 ms |
| p90 latency | 420 ms |
| p95 latency | 650 ms |
| p99 latency | 1100 ms |
| Org-wide goal for p95 | **< 500 ms** |

---

### 3. **Error Breakdown**
| Error Type | Count |
|-----------|-------|
| 5xx internal server errors | 300,000 |
| Partner API timeouts | 200,000 |
| Expected 4xx validation errors | 100,000 |

---

### 4. **Traffic Patterns**
- Normal peak: **5,000 requests/sec**  
- Two major spikes at **9,500 requests/sec**, causing:
  - 40% of all 5xx errors  
  - p95 latency up to **1.3s**

---

### 5. **Deployment History**
- 7 deployments in 30 days  
- 2 deployments correlated with error bursts  
- 1 rollback due to performance regression  
- No deployment freeze policy exists

---

### 6. **Business Requirements (Product Input)**
- “We want 100% availability.”  
- “Latency should always be under 300 ms.”  
- “Payments must always work.”

(Use SRE principles to push back where needed.)

---

# Workshop Tasks  
Participants should complete these as groups.

---

## **Task 1 — Identify SLIs**
Using the Google SLI categories:

### Availability SLI  
Decide:
- Do partner timeouts count as failed requests?  
- Do expected 4xx validation errors count?

### Latency SLI  
Define:
- Which latency percentile matters? p95 or p99?  
- What threshold is realistic?

### Quality / Correctness SLI (optional)  
Should payment status correctness be measured?

---

## **Task 2 — Propose SLOs**
Choose realistic SLO targets such as:
- 99.5%  
- 99.9%  
- 99.95%  

Consider:
- Current performance level  
- Customer expectations  
- Production readiness

---

## **Task 3 — Calculate Error Budgets**

Example calculation:

If SLO = **99.9% availability**
- Error budget = 0.1%  
- Allowed failures = 120,000,000 × 0.001 = **120,000**

Actual failures = 600,000  
→ Error budget is exceeded **5×**.

Teams must compute:
- Whether the SLO is met  
- How fast the budget is being burned  
- Implications

---

## **Task 4 — Recommend Actions**
Teams must decide:

### Should deployments be frozen?
Why?

### What reliability improvements are needed?
Examples:
- Autoscaling adjustments  
- Circuit breakers for partner APIs  
- Separating expected vs unexpected 4xx errors  
- Latency optimization

### What new monitoring/alerting is required?
Tie SLIs → alerts.

---

## **Task 5 — Present an SLO Document**
Teams deliver:

1. Selected SLIs  
2. Chosen SLO targets  
3. Error budget results  
4. Performance issues identified  
5. Deployment policy (freeze? slow-roll?)  
6. Engineering recommendations

Reference Documentation you can use: 
Google SRE - SLO Documentation: https://sre.google/workbook/slo-document/


