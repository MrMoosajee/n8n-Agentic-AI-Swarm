# FOUNDRY PHASE 2: ARCHITECTURE GENERATION
## Setup Guide & Documentation

**Status:** Ready for Import  
**Prerequisites:** Phase 1 Complete & Operational  
**Execution Mode:** Automated (Scheduled) + Manual Trigger  

---

## 🎯 WHAT PHASE 2 DOES

**Input:** Projects with `status = 'phase1_complete'` (from Postgres)  
**Process:** 
1. Fetch next project needing architecture
2. Send MRS + Stack Decision to Gemini Pro
3. Generate comprehensive architecture blueprints
4. Store 4 types of blueprints in database

**Output:** 
- File tree (directory structure)
- System architecture (layers, data flow)
- Dependencies (packages, versions)
- Implementation plan (build order)

**Result:** Project marked `status = 'phase2_complete'`, ready for Phase 3 (Code Gen)

---

## 📋 PRE-IMPORT CHECKLIST

### ✅ Verify Phase 1 is Working

```bash
# Check that Phase 1 created at least one project
docker exec -it foundry_db psql -U foundry -d foundry

SELECT 
  id, 
  project_name, 
  status,
  created_at
FROM foundry_projects
WHERE status = 'phase1_complete'
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:** At least 1 row with `status = 'phase1_complete'`

If no projects, run Phase 1 workflow first:
1. Open n8n: http://localhost:5678
2. Execute "Foundry Phase 1: Executive Intake"
3. Input: `{"chatInput": "Build a simple REST API for task management"}`

### ✅ Verify Database Schema

The `foundry_blueprints` table should already exist from `init_db.sql`:

```sql
\d foundry_blueprints
```

**Expected columns:**
- `id` (serial)
- `project_id` (integer, FK to foundry_projects)
- `blueprint_type` (varchar)
- `content` (jsonb)
- `version` (integer)
- `created_at` (timestamp)

If table doesn't exist:
```sql
-- Re-run from init_db.sql
CREATE TABLE IF NOT EXISTS foundry_blueprints (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    blueprint_type VARCHAR(50) NOT NULL,
    content JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blueprint_project ON foundry_blueprints(project_id);
```

---

## 🚀 IMPORT WORKFLOW

### Step 1: Import JSON

1. Open n8n: http://localhost:5678
2. Click **Workflows** → **Import from File**
3. Select: `foundry_phase2_architecture_workflow.json`
4. Click **Import**

### Step 2: Link Credentials

After import, you'll see credential warnings. Link them:

1. **Architect: Gemini Pro** node
   - Click node → Credentials dropdown
   - Select: **Google Gemini API** (same as Phase 1)
   - Save

2. **All Postgres nodes** (7 total):
   - `Fetch Next Project`
   - `Store File Tree`
   - `Store Architecture`
   - `Store Dependencies`
   - `Store Implementation Plan`
   - `Update Project Status`
   - `Log Architecture Activity`
   
   For each:
   - Click node → Credentials dropdown
   - Select: **Foundry DB**
   - Save

3. **Save Workflow** (Ctrl+S or Cmd+S)

---

## ⚙️ CONFIGURATION OPTIONS

### Trigger Configuration

**Default:** Runs every 5 minutes automatically

To change frequency:
1. Click **Schedule Trigger** node
2. Modify **Cron Expression**: `*/5 * * * *`
   - Every 1 minute: `* * * * *`
   - Every 10 minutes: `*/10 * * * *`
   - Every hour: `0 * * * *`
3. Save workflow

**Manual Trigger:** You can also execute on-demand:
- Click **Execute Workflow** button
- Useful for testing or immediate processing

### Gemini Configuration

**Current Settings:**
- Model: `gemini-1.5-pro` (high quality, detailed architecture)
- Temperature: `0.4` (balanced creativity)
- Max Tokens: `8192` (large architecture documents)

To adjust:
1. Click **Architect: Gemini Pro** node
2. Edit `generationConfig`:
   ```json
   {
     "temperature": 0.4,     // Lower = more deterministic (0.0-1.0)
     "maxOutputTokens": 8192 // Increase for complex projects
   }
   ```

**Alternative Models:**
- `gemini-1.5-flash` - Faster, cheaper, good for simple projects
- `gemini-2.0-flash-exp` - Latest experimental (if available)

---

## 🧪 TESTING PHASE 2

### Test 1: Manual Execution

**Goal:** Verify the workflow processes one project

**Steps:**
1. Ensure Phase 1 has created at least one project
2. Open Phase 2 workflow in n8n
3. Click **Execute Workflow** (big play button)
4. Watch execution flow (should turn green)

**Expected Result:**
- ✅ All nodes execute successfully (green checkmarks)
- ✅ "Success Message" node shows: "Phase 2 Complete: Architecture generated for '[project_name]'"

### Test 2: Verify Database

```sql
-- Check blueprints were created
SELECT 
  bp.id,
  bp.project_id,
  bp.blueprint_type,
  bp.created_at,
  p.project_name
FROM foundry_blueprints bp
JOIN foundry_projects p ON p.id = bp.project_id
ORDER BY bp.created_at DESC
LIMIT 20;
```

**Expected:** 4 rows per project:
- `file_tree`
- `architecture`
- `dependencies`
- `implementation_plan`

### Test 3: Inspect Architecture Content

```sql
-- View file tree blueprint
SELECT 
  project_id,
  content->'structure' as file_structure
FROM foundry_blueprints
WHERE blueprint_type = 'file_tree'
ORDER BY created_at DESC
LIMIT 1;

-- View architecture layers
SELECT 
  project_id,
  content->'layers' as architecture_layers
FROM foundry_blueprints
WHERE blueprint_type = 'architecture'
ORDER BY created_at DESC
LIMIT 1;

-- View dependencies
SELECT 
  project_id,
  content as dependencies
FROM foundry_blueprints
WHERE blueprint_type = 'dependencies'
ORDER BY created_at DESC
LIMIT 1;
```

**Expected:** Valid JSONB with detailed architecture specifications

### Test 4: Verify Project Status Update

```sql
-- Check project moved to phase2_complete
SELECT 
  id,
  project_name,
  status,
  updated_at
FROM foundry_projects
WHERE status = 'phase2_complete'
ORDER BY updated_at DESC;
```

**Expected:** Project(s) with `status = 'phase2_complete'`

### Test 5: Check Agent Logs

```sql
-- View architect activity
SELECT 
  project_id,
  agent_role,
  action,
  model_used,
  success,
  created_at
FROM foundry_agent_log
WHERE agent_role = 'architect'
ORDER BY created_at DESC
LIMIT 10;
```

**Expected:** Log entries showing successful architecture generation

---

## 🔄 WORKFLOW BEHAVIOR

### Automatic Processing

Once activated, Phase 2 will:
1. **Every 5 minutes**: Check for new projects
2. **If found**: Process ONE project (FIFO - oldest first)
3. **If not found**: Exit gracefully with "No work" message
4. **Repeat**: Next scheduled run

**Why one at a time?**
- Respects Gemini API rate limits (15 req/min free tier)
- Avoids overloading Postgres with concurrent writes
- Allows monitoring each project's progress
- Prevents duplicate processing (SQL query excludes processed projects)

### Handling Multiple Projects

If you have 10 projects from Phase 1:
- 5 min intervals → 10 projects = 50 minutes total
- Can speed up by changing cron to `*/1 * * * *` (every minute)
- Or manually trigger multiple times

### Idempotency

**Safe to re-run:** The SQL query explicitly excludes projects that already have blueprints:

```sql
WHERE id NOT IN (
  SELECT DISTINCT project_id 
  FROM foundry_blueprints 
  WHERE blueprint_type = 'file_tree'
)
```

This prevents duplicate architecture generation.

---

## 🐛 TROUBLESHOOTING

### Error: "No projects found"

**Cause:** No projects with `status = 'phase1_complete'`

**Solution:**
```sql
-- Check project statuses
SELECT status, COUNT(*) 
FROM foundry_projects 
GROUP BY status;
```

If all are `intake` or `phase2_complete`:
- Run Phase 1 workflow to create new projects
- Or manually set a project back: `UPDATE foundry_projects SET status = 'phase1_complete' WHERE id = X;`

---

### Error: "Gemini API quota exceeded"

**Symptom:**
```
429 Resource Exhausted
Quota exceeded for quota metric 'Generate Content API requests per minute'
```

**Causes:**
- Free tier: 15 requests/minute
- Phase 2 uses 1 request per project
- If running too frequently, may hit limit

**Solutions:**
1. **Reduce trigger frequency:**
   - Change cron to `*/5 * * * *` (every 5 min instead of 1)
   
2. **Wait and retry:**
   - Quota resets every minute
   - Workflow will succeed on next scheduled run

3. **Switch to Flash model (faster, more quota):**
   ```json
   "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
   ```

---

### Error: "Failed to parse Gemini JSON response"

**Cause:** Gemini returned invalid JSON or non-JSON text

**Debug:**
1. Click **Architect: Gemini Pro** node
2. Check output in right panel
3. Look at `candidates[0].content.parts[0].text`

**Common Issues:**
- Gemini returned markdown with explanation before JSON
- JSON has trailing commas or syntax errors

**Fix:** The Parse Architecture node already handles:
- Markdown code blocks (```json ... ```)
- Text before/after JSON (extracts via regex)

If still failing, check:
```javascript
// In Parse Architecture node, add more logging
console.log('Raw Gemini text:', generatedText);
```

---

### Error: "Relation 'foundry_blueprints' does not exist"

**Cause:** Database schema not initialized

**Solution:**
```bash
# Re-run database initialization
docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql

# Verify table exists
docker exec foundry_db psql -U foundry -d foundry -c "\d foundry_blueprints"
```

---

### Error: "Foreign key violation"

**Symptom:**
```
ERROR: insert or update on table "foundry_blueprints" violates foreign key constraint
```

**Cause:** Trying to insert blueprint for non-existent project_id

**Solution:**
```sql
-- Verify project exists
SELECT id, project_name FROM foundry_projects WHERE id = X;
```

Should not happen if using the workflow's SQL query, but can occur if manually testing.

---

### Slow Execution (>30 seconds per project)

**Expected Duration:** 10-20 seconds per project
- Fetch: <1s
- Gemini: 5-15s (depends on complexity)
- Store: <1s
- Update: <1s

**If slower:**
1. **Check Gemini latency:**
   - Click Architect node → Check execution time
   - If >20s, consider using `gemini-1.5-flash`

2. **Check database load:**
   ```bash
   docker stats foundry_db
   ```
   - If CPU >80%, may need to optimize queries

3. **Network issues:**
   - Test Gemini API directly:
   ```bash
   time curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=YOUR_KEY" \
     -H 'Content-Type: application/json' \
     -d '{"contents":[{"parts":[{"text":"Test"}]}]}'
   ```

---

## 📊 MONITORING & OBSERVABILITY

### Real-Time Monitoring

**n8n Dashboard:**
- View: Workflow → Executions tab
- Shows: Success/failure rate, execution time
- Filter by: Date range, status

**SQL Queries:**

```sql
-- Projects by status
SELECT status, COUNT(*) as count
FROM foundry_projects
GROUP BY status
ORDER BY count DESC;

-- Recent architect activity
SELECT 
  p.project_name,
  al.action,
  al.model_used,
  al.success,
  al.created_at
FROM foundry_agent_log al
JOIN foundry_projects p ON p.id = al.project_id
WHERE al.agent_role = 'architect'
ORDER BY al.created_at DESC
LIMIT 10;

-- Average time between phases
SELECT 
  AVG(EXTRACT(EPOCH FROM (updated_at - created_at))/60) as avg_minutes
FROM foundry_projects
WHERE status = 'phase2_complete';
```

### Alerting (Optional)

Add a notification node at the end:
1. After "Success Message" → Add HTTP Request node
2. Send to: Slack, Discord, email, etc.
3. Payload: `{"text": "{{ $json.message }}"}`

---

## 🎯 EXPECTED OUTCOMES

After running Phase 2 on a project, you should have:

### 1. File Tree Blueprint
Example structure:
```json
{
  "root": "task_manager_api",
  "structure": [
    {
      "path": "src/",
      "type": "directory",
      "purpose": "Main source code"
    },
    {
      "path": "src/main.py",
      "type": "file",
      "purpose": "FastAPI application entry point",
      "priority": 1
    },
    {
      "path": "src/models.py",
      "type": "file",
      "purpose": "SQLAlchemy database models",
      "priority": 2
    },
    ...
  ]
}
```

### 2. Architecture Blueprint
```json
{
  "layers": [
    {
      "name": "API Layer",
      "components": ["FastAPI routes", "Request validation"],
      "tech": "FastAPI + Pydantic"
    },
    {
      "name": "Business Logic",
      "components": ["Task CRUD operations", "User management"],
      "tech": "Python classes"
    }
  ],
  "data_flow": "Client → API → Logic → Database",
  "security": ["JWT authentication", "Input sanitization"],
  "scalability": "Horizontal scaling via Docker containers"
}
```

### 3. Dependencies Blueprint
```json
[
  {
    "name": "fastapi",
    "version": "0.104.1",
    "purpose": "Web framework for API"
  },
  {
    "name": "sqlalchemy",
    "version": "2.0.23",
    "purpose": "Database ORM"
  },
  ...
]
```

### 4. Implementation Plan
```json
[
  {
    "phase": 1,
    "files": ["src/main.py", "requirements.txt", "Dockerfile"],
    "estimated_complexity": "low"
  },
  {
    "phase": 2,
    "files": ["src/models.py", "src/database.py"],
    "estimated_complexity": "medium"
  },
  ...
]
```

---

## 🔜 NEXT STEPS: PHASE 3

Once Phase 2 is working and you have blueprints in the database:

**Phase 3: Code Generation**
- Input: Blueprints from Phase 2
- Process: Use **Ollama Qwen 2.5 Coder 7B** (local) to generate actual code
- Output: Complete, runnable files stored in `foundry_files` table

**Files to create:**
- `foundry_phase3_codegen_workflow.json`
- Each file in the implementation plan gets generated
- Code is validated, linted, and tested before approval

**Why Ollama (local) for code?**
- Privacy: Your code never leaves your machine
- Cost: Zero dollars (vs. Gemini API costs for large codebases)
- Speed: No network latency, local GPU/CPU inference
- Control: Can run offline, no rate limits

---

## 📝 SUMMARY

**Phase 2 Status:** ✅ Ready to Deploy

**What You Have:**
- ✅ Automated workflow (scheduled every 5 min)
- ✅ Comprehensive architecture generation via Gemini
- ✅ 4 types of blueprints stored in Postgres
- ✅ Project status tracking
- ✅ Full audit logs

**What To Do:**
1. Import `foundry_phase2_architecture_workflow.json`
2. Link Gemini + Postgres credentials
3. Activate workflow
4. Monitor executions (n8n UI + SQL queries)

**Next Milestone:** Phase 3 (Code Generation with Ollama)

---

🏭 **THE FOUNDRY COUNCIL EXPANDS: ARCHITECT AGENT NOW OPERATIONAL**
