# FOUNDRY PHASE 1 - TESTING CHECKLIST
## Validation Protocol for Executive Intake Workflow

**Date:** 2026-01-28  
**Version:** 2.1  
**Status:** Pre-Production Testing  

---

## 📋 PRE-TEST SETUP

### ✅ Infrastructure Checks

```bash
# Run this first to verify baseline
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

- [ ] `foundry_n8n` is running and healthy
- [ ] `foundry_db` is running and healthy
- [ ] `foundry_ollama` is running (for future phases)
- [ ] `foundry_memory` is running (for future phases)
- [ ] n8n accessible at http://localhost:5678
- [ ] Database accessible via `docker exec -it foundry_db psql -U foundry -d foundry`

### ✅ Database Schema

```sql
-- Run in postgres shell
\dt foundry_*
```

Expected tables:
- [ ] `foundry_projects`
- [ ] `foundry_blueprints`
- [ ] `foundry_files`
- [ ] `foundry_tests`
- [ ] `foundry_agent_log`

```sql
-- Verify foundry_projects structure
\d foundry_projects
```

Expected columns:
- [ ] `id` (serial)
- [ ] `project_name` (varchar)
- [ ] `mrs_data` (jsonb)
- [ ] `stack_decision` (jsonb)
- [ ] `status` (varchar)
- [ ] `created_at` (timestamp)

### ✅ Credentials Configured

In n8n (Settings → Credentials):
- [ ] "Google Gemini API" exists (type: Google API)
- [ ] "Groq Header" exists (type: Header Auth)
- [ ] "Foundry DB" exists (type: Postgres)
- [ ] All credentials test successfully

---

## 🧪 TEST SUITE 1: INDIVIDUAL NODES

### Test 1.1: Chat Trigger
**Goal:** Verify manual trigger accepts input

**Steps:**
1. Open workflow in n8n
2. Click "Chat Trigger" node
3. Click "Execute Node"
4. Enter test input: `{"chatInput": "test message"}`
5. Verify output contains: `chatInput: "test message"`

**Expected Result:** ✅ Node executes, output visible in panel

**Status:** [ ] PASS  [ ] FAIL  

**Notes:**
```
Time: _____
Error (if any): _____
```

---

### Test 1.2: Extract Chat Input
**Goal:** Verify Set node extracts user_request

**Steps:**
1. Click "Extract Chat Input" node
2. Provide input from previous test
3. Execute node
4. Verify output contains: `user_request: "test message"`

**Expected Result:** ✅ Variable set correctly

**Status:** [ ] PASS  [ ] FAIL

---

### Test 1.3: Liaison - Gemini (HTTP)
**Goal:** Verify Gemini API connectivity and JSON response

**Test Input:**
```json
{
  "user_request": "Build a simple calculator app that can add and subtract numbers"
}
```

**Steps:**
1. Click "Liaison: Gemini (HTTP)" node
2. Execute with test input
3. Check response structure

**Expected Response Structure:**
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\"project_name\":\"...\", \"description\":\"...\", ...}"
          }
        ]
      }
    }
  ]
}
```

**Status:** [ ] PASS  [ ] FAIL  

**Checklist:**
- [ ] HTTP 200 status
- [ ] Response contains `candidates` array
- [ ] `text` field contains JSON (may be in markdown)
- [ ] Execution time < 15 seconds

**Notes:**
```
Response Time: _____ seconds
Token Usage: _____ (if shown)
Error (if any): _____
```

---

### Test 1.4: Parse Gemini JSON
**Goal:** Verify JSON extraction and parsing

**Steps:**
1. Execute with Gemini response from Test 1.3
2. Check output has `mrs` field
3. Verify MRS structure

**Expected Output:**
```json
{
  "mrs": {
    "project_name": "Calculator App",
    "description": "...",
    "requirements": ["addition", "subtraction"],
    "constraints": {...},
    "success_criteria": [...]
  }
}
```

**Status:** [ ] PASS  [ ] FAIL

**Checklist:**
- [ ] `mrs` object exists
- [ ] All required MRS fields present
- [ ] No parsing errors
- [ ] Valid JSON structure

---

### Test 1.5: Strategist - Groq Llama 3.3
**Goal:** Verify Groq API and stack recommendation

**Steps:**
1. Execute with MRS from Test 1.4
2. Check Groq response

**Expected Response:**
```json
{
  "choices": [
    {
      "message": {
        "content": "{\"recommended_stack\": {...}, \"alternative_stacks\": []}"
      }
    }
  ]
}
```

**Status:** [ ] PASS  [ ] FAIL

**Checklist:**
- [ ] HTTP 200 status
- [ ] Response contains `choices` array
- [ ] `content` has stack recommendation
- [ ] Execution time < 10 seconds

**Common Issues:**
- 429 Rate Limit → Wait 60 seconds
- 401 Unauthorized → Check Groq API key

---

### Test 1.6: Combine Results
**Goal:** Verify data aggregation

**Steps:**
1. Execute with Groq response
2. Verify combined output

**Expected Output:**
```json
{
  "mrs": {...},
  "stack_decision": {
    "recommended_stack": {
      "primary_language": "Python",
      "framework": "...",
      "database": "...",
      "reasoning": "..."
    }
  },
  "timestamp": "2026-01-28T...",
  "status": "phase1_complete"
}
```

**Status:** [ ] PASS  [ ] FAIL

**Checklist:**
- [ ] `mrs` preserved from earlier step
- [ ] `stack_decision` parsed correctly
- [ ] `timestamp` is ISO 8601 format
- [ ] `status` = "phase1_complete"

---

### Test 1.7: Store in Postgres
**Goal:** Verify database insert

**Steps:**
1. Execute with combined data
2. Check Postgres node output
3. Verify in database

**Verification Query:**
```sql
SELECT 
  project_name, 
  status, 
  created_at,
  mrs_data->>'description' as description,
  stack_decision->'recommended_stack'->>'primary_language' as language
FROM foundry_projects 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected Result:** ✅ Row inserted with all fields populated

**Status:** [ ] PASS  [ ] FAIL

**Checklist:**
- [ ] Insert succeeded (green checkmark)
- [ ] Row visible in database
- [ ] JSONB fields parseable
- [ ] Timestamp correct

---

## 🚀 TEST SUITE 2: END-TO-END EXECUTION

### Test 2.1: Simple Project Request
**Input:**
```json
{
  "chatInput": "I need a REST API for a todo list. Users should be able to create, read, update, and delete tasks."
}
```

**Execute Full Workflow:**
1. Click "Execute Workflow" (main play button)
2. Enter input above
3. Wait for completion (all nodes green)

**Expected Outcome:**
- [ ] Workflow completes without errors
- [ ] Database has new entry
- [ ] MRS includes: CRUD operations, REST API
- [ ] Stack recommendation is sensible (e.g., Python + FastAPI or Node + Express)

**Execution Time:** _____ seconds (Target: < 20 sec)

**Status:** [ ] PASS  [ ] FAIL

---

### Test 2.2: Complex Project Request
**Input:**
```json
{
  "chatInput": "Build a real-time chat application with authentication, message history, and file sharing. It should scale to 10,000 concurrent users and be secure."
}
```

**Expected Outcome:**
- [ ] MRS captures: real-time, auth, scaling, security
- [ ] Stack recommendation addresses concurrency (e.g., Go, WebSockets, Redis)
- [ ] Reasoning mentions scale requirements

**Status:** [ ] PASS  [ ] FAIL

---

### Test 2.3: Ambiguous Request (Edge Case)
**Input:**
```json
{
  "chatInput": "Make something cool"
}
```

**Expected Behavior:**
- [ ] Liaison asks clarifying questions in MRS OR
- [ ] Liaison makes reasonable assumptions and documents them

**Status:** [ ] PASS  [ ] FAIL  [ ] EXPECTED_DEGRADATION

---

### Test 2.4: Non-English Request (Internationalization)
**Input:**
```json
{
  "chatInput": "Ek wil 'n webwerf hê vir my besigheid. Dit moet professioneel lyk."
}
```

**Expected Outcome:**
- [ ] Gemini understands Afrikaans
- [ ] MRS generated in English (standard format)
- [ ] Stack recommendation is reasonable

**Status:** [ ] PASS  [ ] FAIL

---

### Test 2.5: Rate Limit Handling
**Test:** Execute workflow 50 times rapidly

**Steps:**
```bash
# Automated test script
for i in {1..50}; do
  echo "Test $i"
  # Trigger n8n workflow via webhook (if configured)
  # OR manually execute 50 times
done
```

**Expected Behavior:**
- [ ] Groq returns 429 after ~30 requests
- [ ] Workflow fails gracefully (error visible)
- [ ] Database NOT corrupted
- [ ] After 60 seconds, workflow works again

**Status:** [ ] PASS  [ ] FAIL

---

## 📊 TEST SUITE 3: DATA INTEGRITY

### Test 3.1: Concurrent Executions
**Test:** Run 3 workflows simultaneously with different inputs

**Steps:**
1. Open 3 browser tabs with n8n
2. Execute workflow in each with different chat inputs
3. Verify database has 3 distinct entries

**Expected Outcome:**
- [ ] All 3 executions succeed
- [ ] No data mixing between executions
- [ ] All 3 rows in database have correct project_name

**Status:** [ ] PASS  [ ] FAIL

---

### Test 3.2: JSON Escaping
**Input with special characters:**
```json
{
  "chatInput": "Build an app that processes JSON with \"quotes\", 'apostrophes', and \\ backslashes"
}
```

**Expected Outcome:**
- [ ] No SQL injection
- [ ] No JSON parsing errors
- [ ] Special characters preserved in database

**Status:** [ ] PASS  [ ] FAIL

---

### Test 3.3: Large Input
**Input:** 5000+ character description

```json
{
  "chatInput": "Build a comprehensive ERP system with modules for: [paste lorem ipsum x100 here]"
}
```

**Expected Outcome:**
- [ ] Gemini handles large input (or truncates gracefully)
- [ ] Postgres stores full MRS
- [ ] No memory errors

**Status:** [ ] PASS  [ ] FAIL

---

## 🛡️ TEST SUITE 4: ERROR HANDLING

### Test 4.1: Invalid Gemini API Key
**Test:** Temporarily break Gemini credential

**Steps:**
1. Edit "Google Gemini API" credential
2. Change API key to invalid value
3. Execute workflow
4. Restore correct API key

**Expected Outcome:**
- [ ] Node shows red X
- [ ] Error message is clear: "401 Unauthorized"
- [ ] Workflow stops (doesn't continue to Groq)
- [ ] No database insert

**Status:** [ ] PASS  [ ] FAIL

---

### Test 4.2: Invalid Groq API Key
**Test:** Break Groq credential

**Expected Outcome:**
- [ ] Liaison succeeds (Gemini)
- [ ] Strategist fails (Groq)
- [ ] Error message clear
- [ ] Database entry NOT created (Postgres node doesn't execute)

**Status:** [ ] PASS  [ ] FAIL

---

### Test 4.3: Database Connection Lost
**Test:** Stop database container mid-execution

```bash
# In terminal
docker stop foundry_db
# Wait 5 seconds
docker start foundry_db
```

**Expected Outcome:**
- [ ] Postgres node fails with connection error
- [ ] Error logged in n8n
- [ ] Workflow can be retried successfully after DB restart

**Status:** [ ] PASS  [ ] FAIL

---

### Test 4.4: Malformed Gemini Response
**Test:** Force Gemini to return non-JSON

**Simulation:** Modify Parse Gemini JSON node to receive:
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {"text": "I cannot help with that request."}
        ]
      }
    }
  ]
}
```

**Expected Outcome:**
- [ ] Parse node throws error
- [ ] Error message: "Failed to parse Gemini JSON response"
- [ ] Workflow stops cleanly

**Status:** [ ] PASS  [ ] FAIL

---

## 📈 PERFORMANCE BENCHMARKS

### Benchmark 1: Baseline Performance
**Test:** 10 sequential executions

**Metrics to Record:**

| Run | Total Time (s) | Gemini Time (s) | Groq Time (s) | DB Insert (ms) |
|-----|----------------|-----------------|---------------|----------------|
| 1   |                |                 |               |                |
| 2   |                |                 |               |                |
| 3   |                |                 |               |                |
| ... |                |                 |               |                |
| 10  |                |                 |               |                |

**Averages:**
- Total: _____ seconds (Target: < 20s)
- Gemini: _____ seconds
- Groq: _____ seconds
- DB Insert: _____ ms

---

### Benchmark 2: Memory Usage
**Test:** Monitor n8n container during execution

```bash
# Run this during workflow execution
docker stats foundry_n8n --no-stream
```

**Metrics:**
- Memory Usage: _____ MB (Limit: 4096 MB)
- Memory Percent: _____ % (Target: < 80%)
- CPU Percent: _____ % (Target: < 90% sustained)

**Status:** [ ] PASS  [ ] FAIL

---

## ✅ FINAL VALIDATION

### Production Readiness Checklist

**Infrastructure:**
- [ ] All containers start automatically (`restart: unless-stopped`)
- [ ] Database has backups configured (separate from this test)
- [ ] n8n credentials are secured (not in version control)

**Workflow:**
- [ ] All nodes have descriptive names
- [ ] Error handling is graceful
- [ ] Execution time < 30 seconds for 95th percentile
- [ ] Success rate > 95% across 20+ test runs

**Documentation:**
- [ ] SETUP_GUIDE.md is accurate
- [ ] TROUBLESHOOTING.md covers observed errors
- [ ] ARCHITECTURE.md reflects current implementation

**Next Steps:**
- [ ] Phase 1 marked as COMPLETE
- [ ] Phase 2 (Architecture) design begun
- [ ] Handover document created for next engineer

---

## 📝 TEST SUMMARY

**Date Completed:** __________  
**Tested By:** __________  
**Total Tests:** 25  
**Passed:** __ / 25  
**Failed:** __ / 25  
**Blocked:** __ / 25  

**Critical Issues Found:**
1. _____
2. _____
3. _____

**Recommendation:**
- [ ] ✅ APPROVED FOR PRODUCTION (95%+ pass rate)
- [ ] ⚠️  NEEDS MINOR FIXES (<95% pass rate)
- [ ] ❌ MAJOR ISSUES (Critical failures)

**Sign-Off:**
```
Engineer: ___________
Date: ___________
Signature: ___________
```

---

**"Measure twice, cut once. Test thoroughly, deploy confidently."** 🏭
