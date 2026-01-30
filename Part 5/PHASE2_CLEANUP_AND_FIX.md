# PHASE 2 CLEANUP AND FINAL FIX
## You're Almost There!

**Current Status:**
- ✅ Blueprints are being created (6 found, should be 4)
- ✅ Project status updated to 'phase2_complete'
- ❌ Logging not working (last_log_action is empty)
- ⚠️  Duplicate blueprints (6 instead of 4)

---

## 🧹 STEP 1: CLEAN UP DUPLICATES

Run this in your database:

```bash
docker exec -it foundry_db psql -U foundry -d foundry
```

```sql
-- Check what you have
SELECT 
    id,
    project_id,
    blueprint_type,
    created_at
FROM foundry_blueprints
WHERE project_id = 9
ORDER BY created_at;

-- You'll probably see duplicates
-- Let's keep only the latest of each type

-- Delete duplicates, keeping only the most recent
DELETE FROM foundry_blueprints
WHERE id NOT IN (
    SELECT MAX(id)
    FROM foundry_blueprints
    GROUP BY project_id, blueprint_type
);

-- Verify - should now have exactly 4
SELECT 
    project_id,
    blueprint_type,
    created_at
FROM foundry_blueprints
WHERE project_id = 9
ORDER BY blueprint_type;
```

**Expected output:**
```
 project_id | blueprint_type      | created_at
------------+--------------------+------------------------
          9 | architecture        | 2026-01-29 ...
          9 | dependencies        | 2026-01-29 ...
          9 | file_tree           | 2026-01-29 ...
          9 | implementation_plan | 2026-01-29 ...
```

---

## 🔧 STEP 2: FIX THE LOGGING NODE

The "Log Architecture Activity" node isn't inserting data. Let's fix it.

### Check Current Log Table

```sql
-- See if log table exists and has correct structure
\d foundry_agent_log

-- Check if any logs exist at all
SELECT COUNT(*) FROM foundry_agent_log;

-- Check recent logs
SELECT * FROM foundry_agent_log ORDER BY created_at DESC LIMIT 5;
```

### Fix the Log Node in n8n

**Click "Log Architecture Activity" node**

**Replace the query with this:**

```sql
INSERT INTO foundry_agent_log (
    project_id,
    agent_role,
    action,
    input_data,
    output_data,
    model_used,
    success
) VALUES (
    {{ $node["Parse Architecture"].json.project_id }},
    'architect',
    'generate_blueprints',
    $1::jsonb,
    $2::jsonb,
    'gemini-1.5-pro',
    true
)
```

**Query Parameters:**
- **Parameter 1:** `{{ JSON.stringify({ project: $node["Parse Architecture"].json.project_name }) }}`
- **Parameter 2:** `{{ JSON.stringify({ blueprints_created: 4, timestamp: $node["Parse Architecture"].json.timestamp }) }}`

**OR simpler version (no parameters):**

```sql
INSERT INTO foundry_agent_log (
    project_id,
    agent_role,
    action,
    model_used,
    success
) VALUES (
    {{ $node["Parse Architecture"].json.project_id }},
    'architect',
    'generate_blueprints',
    'gemini-1.5-pro',
    true
)
```

---

## 🚫 STEP 3: PREVENT DUPLICATE INSERTS

The fact you have 6 blueprints means the Execute Query ran more than once, or the Code node returned more items than expected.

### Add a Limit Node

**Between "Execute Query" and "Update Status":**

```
Execute Query (inserts 4 blueprints)
    ↓
Limit (only 1 item passes through) ← ADD THIS
    ↓
Update Status (runs once)
    ↓
Log Activity (runs once)
```

**Limit Node Configuration:**
1. Click **+** after Execute Query
2. Add **"Limit"** node
3. Configure:
   - **Max Items:** 1
   - **Keep:** First Item

This ensures Update and Log only run ONCE, even though Execute Query ran 4 times.

---

## 🔍 STEP 4: VERIFY CODE NODE OUTPUT

**Click "Prepare Blueprints" (or whatever you named your Code node)**

**Verify it returns exactly 4 items:**

```javascript
const projectId = $json.project_id;
const projectName = $json.project_name;
const arch = $json.architecture;

// Should return EXACTLY 4 items
return [
  { json: { pid: projectId, pname: projectName, type: 'file_tree', data: arch.file_tree } },
  { json: { pid: projectId, pname: projectName, type: 'architecture', data: arch.architecture } },
  { json: { pid: projectId, pname: projectName, type: 'dependencies', data: arch.dependencies } },
  { json: { pid: projectId, pname: projectName, type: 'implementation_plan', data: arch.implementation_order } }
];
```

**Test it:**
1. Click the Code node
2. Click "Execute Node"
3. Check output panel - should show "4 items"

---

## 🧪 STEP 5: TEST COMPLETE WORKFLOW

### Before Testing - Reset Project Status

```sql
-- Reset the test project back to phase1_complete
UPDATE foundry_projects 
SET status = 'phase1_complete' 
WHERE id = 9;

-- Delete blueprints for clean test
DELETE FROM foundry_blueprints WHERE project_id = 9;

-- Delete logs for clean test
DELETE FROM foundry_agent_log WHERE project_id = 9;
```

### Run Full Workflow

1. In n8n, click **"Execute Workflow"**
2. Wait for completion (all green)
3. Check results:

```sql
-- Should have exactly 4 blueprints
SELECT 
    project_id,
    blueprint_type
FROM foundry_blueprints
WHERE project_id = 9
ORDER BY blueprint_type;

-- Should show 4 rows

-- Should have status updated
SELECT status FROM foundry_projects WHERE id = 9;

-- Should return: phase2_complete

-- Should have 1 log entry
SELECT 
    agent_role,
    action,
    model_used,
    success,
    created_at
FROM foundry_agent_log
WHERE project_id = 9;

-- Should return 1 row with architect, generate_blueprints
```

---

## ✅ EXPECTED FINAL STATE

After a successful Phase 2 run:

```sql
-- Complete verification query
SELECT 
    p.id,
    p.project_name,
    p.status,
    COUNT(bp.id) as blueprint_count,
    al.action as last_log_action,
    al.created_at as last_log_time
FROM foundry_projects p
LEFT JOIN foundry_blueprints bp ON bp.project_id = p.id
LEFT JOIN foundry_agent_log al ON al.project_id = p.id AND al.agent_role = 'architect'
WHERE p.id = 9
GROUP BY p.id, p.project_name, p.status, al.action, al.created_at;
```

**Expected output:**
```
 id | project_name           | status          | blueprint_count | last_log_action       | last_log_time
----+------------------------+-----------------+-----------------+----------------------+-------------------
  9 | Test Blueprint Storage | phase2_complete |               4 | generate_blueprints  | 2026-01-29 ...
```

**Key indicators of success:**
- ✅ blueprint_count = 4 (exactly, not 6 or 8)
- ✅ status = 'phase2_complete'
- ✅ last_log_action = 'generate_blueprints' (NOT NULL)
- ✅ last_log_time has a timestamp (NOT NULL)

---

## 📋 FINAL WORKFLOW STRUCTURE

Your complete working workflow should be:

```
1. Schedule Trigger (every 5 min)
    ↓
2. Fetch Next Project (SQL)
    ↓
3. Project Found? (IF node)
    ↓ (true path)
4. Build Architect Prompt (Code)
    ↓
5. Architect: Gemini Pro (HTTP)
    ↓
6. Parse Architecture (Code)
    ↓
7. Prepare Blueprints (Code - outputs 4 items)
    ↓
8. Execute Query: Insert (Postgres - runs 4x)
    ↓
9. Limit (1 item) ← IMPORTANT!
    ↓
10. Update Status (Postgres - runs 1x)
    ↓
11. Log Activity (Postgres - runs 1x)
    ↓
12. Success Message (Set)
```

---

## 🐛 TROUBLESHOOTING

### If You Still Get Duplicates

**Option A: Add UNIQUE constraint**
```sql
-- Prevent duplicates at database level
CREATE UNIQUE INDEX idx_unique_blueprint 
ON foundry_blueprints(project_id, blueprint_type);
```

Now if Execute Query tries to insert duplicates, it will fail silently (with ON CONFLICT DO NOTHING).

**Option B: Add ON CONFLICT to query**

In "Execute Query" node:
```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES ({{ $json.pid }}, '{{ $json.type }}', $1::jsonb, 1)
ON CONFLICT (project_id, blueprint_type) DO NOTHING
```

(Requires the UNIQUE index from Option A first)

### If Logging Still Fails

**Test manually:**
```sql
INSERT INTO foundry_agent_log (project_id, agent_role, action, model_used, success)
VALUES (9, 'test', 'test_action', 'test_model', true);

-- Check if it inserted
SELECT * FROM foundry_agent_log ORDER BY created_at DESC LIMIT 1;
```

If this fails, there's a schema issue. Run:
```sql
-- Recreate log table
DROP TABLE IF EXISTS foundry_agent_log;

CREATE TABLE foundry_agent_log (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    agent_role VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    input_data JSONB,
    output_data JSONB,
    model_used VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🎯 NEXT STEPS

Once Phase 2 is fully working:

1. ✅ Clean up duplicates
2. ✅ Fix logging
3. ✅ Add Limit node
4. ✅ Test with fresh project
5. ✅ Verify all outputs correct
6. 🚀 **Ready for Phase 3: Code Generation!**

---

🏭 **"CLEAN THE DATA, FIX THE FLOW, PHASE 2 COMPLETE!"**
