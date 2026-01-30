# FOUNDRY PHASE 2 - TESTING CHECKLIST
## Architecture Generation Validation Protocol

**Date:** 2026-01-28  
**Version:** 2.1  
**Prerequisite:** Phase 1 Complete & Tested  

---

## 📋 PRE-TEST VALIDATION

Run the validation script first:

```bash
chmod +x validate_phase2.sh
./validate_phase2.sh
```

**Expected:** All critical checks pass (0 failures)

---

## 🧪 TEST SUITE 1: SINGLE PROJECT PROCESSING

### Test 1.1: Manual Trigger - Simple Project

**Setup:**
```sql
-- Ensure you have a test project
INSERT INTO foundry_projects (
    project_name,
    mrs_data,
    stack_decision,
    status
) VALUES (
    'Test API',
    '{"project_name": "Test API", "description": "Simple REST API", "requirements": ["CRUD operations"], "constraints": {"budget": "R0", "timeline": "2 hours"}, "success_criteria": ["API responds correctly"]}'::jsonb,
    '{"recommended_stack": {"primary_language": "Python", "framework": "FastAPI", "database": "SQLite", "reasoning": "Simple and fast"}}'::jsonb,
    'phase1_complete'
) RETURNING id;
```

**Execution:**
1. Open Phase 2 workflow in n8n
2. Click **Execute Workflow** (play button)
3. Wait 10-20 seconds

**Expected Results:**

| Node | Status | Output Check |
|------|--------|--------------|
| Schedule Trigger | ✅ Green | Executes |
| Fetch Next Project | ✅ Green | Returns 1 row with project data |
| Project Found? | ✅ Green | Takes "true" path |
| Build Architect Prompt | ✅ Green | `prompt` field contains full context |
| Architect: Gemini Pro | ✅ Green | Response time: 5-15 seconds |
| Parse Architecture | ✅ Green | `architecture` object with all fields |
| Store File Tree | ✅ Green | Inserts 1 row |
| Store Architecture | ✅ Green | Inserts 1 row |
| Store Dependencies | ✅ Green | Inserts 1 row |
| Store Implementation Plan | ✅ Green | Inserts 1 row |
| Update Project Status | ✅ Green | Updates 1 row |
| Log Architecture Activity | ✅ Green | Inserts 1 log entry |
| Success Message | ✅ Green | Shows completion message |

**Verification Queries:**

```sql
-- 1. Check blueprints created
SELECT 
    blueprint_type,
    json_array_length(content::json->'structure') as item_count,
    created_at
FROM foundry_blueprints
WHERE project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API')
ORDER BY blueprint_type;

-- Expected: 4 rows (file_tree, architecture, dependencies, implementation_plan)

-- 2. Check project status updated
SELECT id, project_name, status, updated_at
FROM foundry_projects
WHERE project_name = 'Test API';

-- Expected: status = 'phase2_complete'

-- 3. Check agent log
SELECT agent_role, action, success
FROM foundry_agent_log
WHERE project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API');

-- Expected: 1 row, success = true
```

**Status:** [ ] PASS  [ ] FAIL

**Execution Time:** _____ seconds (Target: < 25s)

**Notes:**
```
_____________________________________
```

---

### Test 1.2: Inspect Architecture Quality

**Goal:** Verify Gemini generated comprehensive, useful blueprints

**Check File Tree:**
```sql
SELECT content::json->'structure' 
FROM foundry_blueprints 
WHERE blueprint_type = 'file_tree' 
  AND project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API')
LIMIT 1;
```

**Quality Criteria:**
- [ ] At least 10 files/directories defined
- [ ] Includes entry point (e.g., `main.py`, `app.js`)
- [ ] Includes configuration files (`requirements.txt`, `Dockerfile`, etc.)
- [ ] Includes test directory
- [ ] Each file has `purpose` field explaining its role
- [ ] Files have `priority` indicating build order

**Check Architecture:**
```sql
SELECT content::json 
FROM foundry_blueprints 
WHERE blueprint_type = 'architecture' 
  AND project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API')
LIMIT 1;
```

**Quality Criteria:**
- [ ] Defines at least 2 layers (e.g., API, Business Logic, Data)
- [ ] Includes data flow description
- [ ] Lists security measures
- [ ] Addresses scalability from MRS requirements
- [ ] Specific to chosen tech stack (FastAPI mentioned in example)

**Check Dependencies:**
```sql
SELECT content::json 
FROM foundry_blueprints 
WHERE blueprint_type = 'dependencies' 
  AND project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API')
LIMIT 1;
```

**Quality Criteria:**
- [ ] At least 3 dependencies listed
- [ ] Each has `name`, `version`, `purpose`
- [ ] Versions are recent/stable (not ancient packages)
- [ ] Includes framework from stack decision (FastAPI in example)

**Check Implementation Plan:**
```sql
SELECT content::json 
FROM foundry_blueprints 
WHERE blueprint_type = 'implementation_plan' 
  AND project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API')
LIMIT 1;
```

**Quality Criteria:**
- [ ] Breaks project into phases (at least 2)
- [ ] Each phase lists specific files
- [ ] Complexity estimates provided (low/medium/high)
- [ ] Logical order (infrastructure → core features → tests)

**Status:** [ ] PASS  [ ] FAIL

---

### Test 1.3: Complex Project

**Setup:**
```sql
INSERT INTO foundry_projects (
    project_name,
    mrs_data,
    stack_decision,
    status
) VALUES (
    'E-Commerce Platform',
    '{"project_name": "E-Commerce Platform", "description": "Full-featured online store with user authentication, product catalog, shopping cart, payment processing, order management, and admin dashboard", "requirements": ["User registration/login", "Product browsing with search/filter", "Shopping cart", "Stripe payment integration", "Order tracking", "Admin panel", "Email notifications", "RESTful API"], "constraints": {"budget": "R0", "timeline": "3 weeks"}, "success_criteria": ["Handles 1000+ concurrent users", "99.9% uptime", "PCI-DSS compliant payments", "Mobile responsive"]}'::jsonb,
    '{"recommended_stack": {"primary_language": "Python", "framework": "Django", "database": "PostgreSQL", "reasoning": "Django provides built-in admin, authentication, and ORM. PostgreSQL for data integrity."}}'::jsonb,
    'phase1_complete'
);
```

**Execution:** Execute Phase 2 workflow

**Expected Outcomes:**
- [ ] Execution time: 15-30 seconds (larger context)
- [ ] File tree has 30+ files (complex project)
- [ ] Architecture includes security layer (PCI compliance mentioned)
- [ ] Dependencies include: Django, PostgreSQL driver, Stripe SDK
- [ ] Implementation plan has 5+ phases

**Status:** [ ] PASS  [ ] FAIL

**Actual Execution Time:** _____ seconds

---

## 🔄 TEST SUITE 2: AUTOMATED PROCESSING

### Test 2.1: Schedule Trigger

**Setup:**
1. Activate Phase 2 workflow (toggle switch ON)
2. Ensure 2-3 projects with `status = 'phase1_complete'`
3. Wait 5 minutes (default cron interval)

**Expected Behavior:**
- [ ] Workflow executes automatically
- [ ] Processes 1 project per run
- [ ] After 3 runs (15 min), all 3 projects processed
- [ ] Subsequent runs show "No Work Message" (no projects left)

**Verification:**
```sql
-- Check execution history
SELECT 
    status,
    COUNT(*) as count
FROM foundry_projects
GROUP BY status;

-- Expected: 
-- phase1_complete: 0
-- phase2_complete: 3 (or however many you created)
```

**Status:** [ ] PASS  [ ] FAIL

---

### Test 2.2: Idempotency (No Duplicate Processing)

**Goal:** Ensure same project isn't processed twice

**Setup:**
1. Run Phase 2 workflow on a project
2. Manually reset project: 
   ```sql
   UPDATE foundry_projects SET status = 'phase1_complete' WHERE id = X;
   ```
   (But do NOT delete blueprints)
3. Run Phase 2 again

**Expected Behavior:**
- [ ] Workflow fetches project
- [ ] BUT sees blueprints already exist (file_tree present)
- [ ] SQL query returns 0 rows
- [ ] "No Work Message" displayed

**Verification:**
```sql
-- Check blueprints count (should still be 4, not 8)
SELECT COUNT(*) 
FROM foundry_blueprints 
WHERE project_id = X;

-- Expected: 4 (not duplicated)
```

**Status:** [ ] PASS  [ ] FAIL

---

## 🚨 TEST SUITE 3: ERROR HANDLING

### Test 3.1: No Projects Available

**Setup:** Ensure all projects are NOT `phase1_complete`
```sql
UPDATE foundry_projects SET status = 'phase2_complete';
```

**Execution:** Run Phase 2 workflow

**Expected Behavior:**
- [ ] "Fetch Next Project" returns 0 rows
- [ ] "Project Found?" takes FALSE path
- [ ] "No Work Message" node executes
- [ ] Workflow completes (no errors)

**Status:** [ ] PASS  [ ] FAIL

---

### Test 3.2: Invalid Gemini API Key

**Setup:**
1. Edit "Google Gemini API" credential
2. Change API key to invalid value
3. Run workflow

**Expected Behavior:**
- [ ] "Architect: Gemini Pro" node fails with RED X
- [ ] Error message: "401 Unauthorized" or similar
- [ ] Workflow stops (doesn't continue to Store nodes)
- [ ] Database NOT modified (project still `phase1_complete`)

**Cleanup:** Restore correct API key

**Status:** [ ] PASS  [ ] FAIL

---

### Test 3.3: Malformed Gemini Response

**Simulation:** Modify "Parse Architecture" node to receive:
```json
{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "I apologize, but I cannot generate that architecture."
      }]
    }
  }]
}
```

**Expected Behavior:**
- [ ] "Parse Architecture" node throws error
- [ ] Error message: "Architecture missing required fields"
- [ ] Workflow stops cleanly

**Note:** In real usage, `responseMimeType: "application/json"` should prevent this, but test error handling anyway.

**Status:** [ ] PASS  [ ] FAIL

---

### Test 3.4: Database Connection Lost

**Setup:**
```bash
# Stop database mid-execution
docker stop foundry_db
sleep 3
docker start foundry_db
```

**Expected Behavior:**
- [ ] One of the Store nodes fails
- [ ] Error: "Connection refused" or timeout
- [ ] Workflow stops with clear error
- [ ] After DB restarts, re-running workflow succeeds

**Status:** [ ] PASS  [ ] FAIL

---

## 📊 TEST SUITE 4: PERFORMANCE & LOAD

### Test 4.1: Batch Processing

**Setup:** Create 10 projects in `phase1_complete` status

**Execution:** Activate workflow, wait ~50 minutes (5 min intervals × 10 projects)

**Metrics to Track:**

| Project # | Execution Time (s) | File Count | Dependencies Count | Status |
|-----------|-------------------|------------|-------------------|--------|
| 1         |                   |            |                   |        |
| 2         |                   |            |                   |        |
| ...       |                   |            |                   |        |
| 10        |                   |            |                   |        |

**Success Criteria:**
- [ ] All 10 projects processed successfully
- [ ] Average execution time < 25 seconds
- [ ] No Gemini rate limit errors (free tier: 15 req/min)
- [ ] Database has 40 blueprint entries (4 per project)

**Status:** [ ] PASS  [ ] FAIL

**Average Time:** _____ seconds

---

### Test 4.2: Memory Usage

**Monitor:** While Phase 2 is running

```bash
docker stats foundry_n8n --no-stream
```

**Metrics:**
- Memory Usage: _____ MB
- Memory Percent: _____ %
- CPU Percent: _____ %

**Limits:**
- Memory < 3GB (out of 4GB limit)
- CPU < 90% sustained

**Status:** [ ] PASS  [ ] FAIL

---

### Test 4.3: Gemini Rate Limiting

**Test:** Execute workflow 20 times rapidly (manually trigger)

**Expected Behavior:**
- [ ] First 15 succeed
- [ ] Requests 16+ return 429 error ("Rate limit exceeded")
- [ ] After 60 seconds, requests succeed again

**Workflow Response:**
- [ ] Clear error message shown in n8n
- [ ] Workflow stops gracefully
- [ ] No partial data written

**Status:** [ ] PASS  [ ] FAIL

---

## 🔍 TEST SUITE 5: DATA INTEGRITY

### Test 5.1: JSONB Validation

**Check:** All blueprint content fields are valid JSON

```sql
-- This should return 0 rows (no invalid JSON)
SELECT 
    id,
    project_id,
    blueprint_type
FROM foundry_blueprints
WHERE NOT (content::text)::json IS NOT NULL;
```

**Expected:** 0 rows

**Status:** [ ] PASS  [ ] FAIL

---

### Test 5.2: Foreign Key Integrity

**Test:** Try to delete a project that has blueprints

```sql
-- Should fail with FK constraint error
DELETE FROM foundry_projects WHERE id = (
    SELECT DISTINCT project_id FROM foundry_blueprints LIMIT 1
);
```

**Expected:** Error message about foreign key constraint

**Alternative (with CASCADE):**
```sql
-- Check cascade delete works
BEGIN;
DELETE FROM foundry_projects WHERE project_name = 'Test API';
-- Check blueprints also deleted
SELECT COUNT(*) FROM foundry_blueprints 
WHERE project_id = (SELECT id FROM foundry_projects WHERE project_name = 'Test API');
-- Should return 0
ROLLBACK; -- Don't actually delete
```

**Status:** [ ] PASS  [ ] FAIL

---

### Test 5.3: Concurrent Writes

**Test:** Run Phase 2 workflow twice simultaneously (two browser tabs)

**Expected Behavior:**
- [ ] Both workflows start
- [ ] ONLY ONE processes the project (SQL query is atomic)
- [ ] Other workflow gets "No Work Message"
- [ ] No duplicate blueprints in database

**Verification:**
```sql
SELECT project_id, COUNT(*) as blueprint_count
FROM foundry_blueprints
GROUP BY project_id
HAVING COUNT(*) != 4;

-- Should return 0 rows (all projects have exactly 4 blueprints)
```

**Status:** [ ] PASS  [ ] FAIL

---

## 🎯 TEST SUITE 6: INTEGRATION WITH PHASE 1

### Test 6.1: End-to-End (Phase 1 → Phase 2)

**Workflow:**
1. Execute Phase 1 with new project request
2. Verify project created with `status = 'phase1_complete'`
3. Wait for Phase 2 auto-trigger (5 min) OR manually trigger
4. Verify blueprints created
5. Verify status updated to `phase2_complete`

**Expected Timeline:**
- Phase 1: ~15 seconds
- Phase 2: ~20 seconds
- Total: ~35 seconds (plus 5 min wait if automated)

**Status:** [ ] PASS  [ ] FAIL

---

### Test 6.2: Stack Consistency

**Goal:** Ensure Phase 2 respects Phase 1's stack decision

**Setup:**
1. Create project in Phase 1 that recommends **Rust**
2. Let Phase 2 generate architecture

**Check File Tree:**
```sql
SELECT content::json->'structure' 
FROM foundry_blueprints 
WHERE blueprint_type = 'file_tree' 
  AND project_id = [rust_project_id];
```

**Validation:**
- [ ] Files have `.rs` extension (not `.py` or `.js`)
- [ ] Includes `Cargo.toml` (Rust's package file)
- [ ] Uses Rust terminology in descriptions

**Status:** [ ] PASS  [ ] FAIL

---

## 📈 FINAL VALIDATION

### Production Readiness Criteria

**Infrastructure:**
- [ ] Phase 2 workflow imported successfully
- [ ] All credentials linked (Gemini + Postgres)
- [ ] Schedule trigger configured (5 min default)
- [ ] Workflow activated (toggle ON)

**Functionality:**
- [ ] Processes projects automatically
- [ ] Generates 4 blueprint types per project
- [ ] Updates project status correctly
- [ ] Logs activity for observability

**Quality:**
- [ ] Blueprints are comprehensive (10+ files in tree)
- [ ] Architecture is tech-stack specific
- [ ] Dependencies are valid and recent
- [ ] Implementation plan is logical

**Performance:**
- [ ] Execution time < 30 seconds per project
- [ ] Memory usage < 3GB
- [ ] No rate limit issues at 5min intervals

**Reliability:**
- [ ] Error handling works (fails gracefully)
- [ ] No duplicate processing (idempotent)
- [ ] Foreign key constraints enforced
- [ ] Audit logs complete

---

## ✅ SIGN-OFF

**Total Tests:** 28  
**Passed:** __ / 28  
**Failed:** __ / 28  
**Pass Rate:** _____%

**Critical Issues:**
1. _____
2. _____

**Recommendation:**
- [ ] ✅ APPROVED FOR PRODUCTION (>90% pass rate)
- [ ] ⚠️  NEEDS FIXES (<90% pass rate)
- [ ] ❌ MAJOR ISSUES

**Next Phase:** Phase 3 (Code Generation with Ollama)

**Tester:** _____________________  
**Date:** _____________________  
**Signature:** _____________________

---

🏭 **"ARCHITECTURE IS NOT AN AFTERTHOUGHT—IT'S THE FOUNDATION."**
