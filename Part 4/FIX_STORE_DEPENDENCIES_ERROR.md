# FIXING "Store Dependencies" Node Error
## Troubleshooting Guide for Phase 2 Database Issues

**Error Shown:** "Problem in node 'Store Dependencies'"  
**Message:** "Invalid input for 'content' [item 0]"  
**Root Cause:** Data format mismatch between n8n output and Postgres JSONB column  

---

## 🎯 IMMEDIATE FIX OPTIONS

### Option 1: Fix via n8n UI (Recommended)

#### Step 1: Check "Parse Architecture" Node Output

1. Click on **"Parse Architecture"** node
2. Click **"Execute Node"** 
3. Look at the output in right panel
4. Verify you see:
   ```json
   {
     "project_id": 1,
     "project_name": "Some Project",
     "architecture": {
       "file_tree": { ... },
       "architecture": { ... },
       "dependencies": [ ... ],  ← This is what we need
       "implementation_order": [ ... ]
     }
   }
   ```

#### Step 2: Fix "Store Dependencies" Node

Click on **"Store Dependencies"** node, then in the right panel:

**Current problematic configuration:**
```json
{
  "project_id": "={{ $json.project_id }}",
  "blueprint_type": "dependencies",
  "content": "={{ JSON.stringify($json.architecture.dependencies) }}"  ← PROBLEM HERE
}
```

**The issue:** `JSON.stringify()` creates a STRING, but Postgres expects JSONB

**FIX #1 - Remove JSON.stringify:**
```json
{
  "project_id": "={{ $json.project_id }}",
  "blueprint_type": "dependencies",
  "content": "={{ $json.architecture.dependencies }}"
}
```

**FIX #2 - Force JSONB cast (if #1 fails):**
Change the "content" field mapping to:
- Type: **JSON** (not String)
- Value: `{{ $json.architecture.dependencies }}`

#### Step 3: Apply Same Fix to Other Store Nodes

**"Store File Tree" node:**
```json
{
  "content": "={{ $json.architecture.file_tree }}"
}
```

**"Store Architecture" node:**
```json
{
  "content": "={{ $json.architecture.architecture }}"
}
```

**"Store Implementation Plan" node:**
```json
{
  "content": "={{ $json.architecture.implementation_order }}"
}
```

#### Step 4: Test

1. Save workflow (Ctrl+S)
2. Execute workflow
3. All Store nodes should turn green ✅

---

### Option 2: Fix via Re-import (Clean Slate)

If the UI fix is tedious:

1. **Delete** current Phase 2 workflow in n8n
2. Run the database fix script:
   ```bash
   ./fix_phase2_db.sh
   ```
3. **Re-import** Phase 2 workflow JSON
4. **Configure all Postgres nodes** with this specific setting:

   For each "Store" node:
   - Click node → Columns section
   - Find "content" mapping
   - **Change type from "String" to "JSON"**
   - Keep value as: `{{ $json.architecture.[blueprint_type] }}`

---

### Option 3: Manual Database Workaround

If n8n keeps failing, insert blueprints directly via SQL:

```bash
# Open postgres shell
docker exec -it foundry_db psql -U foundry -d foundry

# Copy-paste this (replace PROJECT_ID with actual ID):
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES 
    (1, 'file_tree', '{"root": "project", "structure": []}'::jsonb, 1),
    (1, 'architecture', '{"layers": []}'::jsonb, 1),
    (1, 'dependencies', '[]'::jsonb, 1),
    (1, 'implementation_plan', '[]'::jsonb, 1);

# Update project status
UPDATE foundry_projects SET status = 'phase2_complete' WHERE id = 1;
```

Then move to Phase 3 (Code Generation).

---

## 🔍 ROOT CAUSE ANALYSIS

### Why This Happens

**n8n Postgres Node Behavior:**
- When you set a column value with `JSON.stringify(...)`, it creates a TEXT string
- Postgres JSONB columns expect actual JSON data, not stringified JSON
- Result: `"[{\"name\":\"fastapi\"}]"` (string) vs `[{"name":"fastapi"}]` (jsonb)

**The confusion:**
- In JavaScript/n8n Code nodes: `JSON.stringify()` is needed to convert objects to strings
- In n8n Postgres Insert nodes: DON'T use `JSON.stringify()` for JSONB columns
- n8n automatically handles the conversion if you pass the raw object

### Correct Data Flow

```
Gemini Response (JSON string)
    ↓
Parse Architecture (JavaScript parse)
    ↓
$json.architecture.dependencies (JavaScript object)
    ↓
Store Dependencies node (n8n automatically converts to JSONB)
    ↓
Postgres (stores as JSONB)
```

**Wrong flow:**
```
$json.architecture.dependencies (object)
    ↓
JSON.stringify() (converts to string)
    ↓
Store Dependencies node (tries to insert string into JSONB column)
    ↓
ERROR: Invalid input
```

---

## 🧪 TESTING THE FIX

### Test 1: Execute Single Node

1. Click **"Parse Architecture"** node
2. Execute it (play button on node)
3. Verify output has `architecture` object with sub-objects

2. Click **"Store Dependencies"** node
3. Execute it (should use data from Parse Architecture)
4. Should show green checkmark ✅

### Test 2: Full Workflow

1. Execute full workflow
2. All nodes should complete successfully
3. Check database:

```sql
SELECT 
    blueprint_type,
    jsonb_typeof(content) as content_type,
    content
FROM foundry_blueprints
WHERE project_id = (SELECT MAX(id) FROM foundry_projects)
ORDER BY blueprint_type;
```

**Expected output:**
```
 blueprint_type      | content_type | content
---------------------+--------------+------------------
 architecture        | object       | {"layers": [...]}
 dependencies        | array        | [{"name": "..."}]
 file_tree           | object       | {"root": "..."}
 implementation_plan | array        | [{"phase": 1}]
```

**NOT this:**
```
 blueprint_type | content_type | content
----------------+--------------+------------------------
 dependencies   | string       | "[{\"name\":\"...\"}]"  ← WRONG!
```

### Test 3: Verify JSONB Operations Work

```sql
-- This should work (JSONB operations)
SELECT 
    blueprint_type,
    jsonb_array_length(content) as item_count
FROM foundry_blueprints
WHERE blueprint_type IN ('dependencies', 'implementation_plan');

-- If error "cannot get array length of a scalar", content is stored as string (wrong)
```

---

## 📋 CHECKLIST FOR ALL STORE NODES

For **each** of these nodes, verify configuration:

- [ ] **Store File Tree**
  - Column: `content`
  - Type: `JSON` (not String)
  - Value: `{{ $json.architecture.file_tree }}`

- [ ] **Store Architecture**
  - Column: `content`
  - Type: `JSON`
  - Value: `{{ $json.architecture.architecture }}`

- [ ] **Store Dependencies**
  - Column: `content`
  - Type: `JSON`
  - Value: `{{ $json.architecture.dependencies }}`

- [ ] **Store Implementation Plan**
  - Column: `content`
  - Type: `JSON`
  - Value: `{{ $json.architecture.implementation_order }}`

**Critical:** No `JSON.stringify()` in any of these values!

---

## 🆘 IF STILL FAILING

### Check 1: Column Type in Database

```sql
\d foundry_blueprints
```

Look for:
```
 content | jsonb | not null
```

If it shows `text` or `json` (not `jsonb`), fix:
```sql
ALTER TABLE foundry_blueprints 
ALTER COLUMN content TYPE jsonb USING content::jsonb;
```

### Check 2: n8n Postgres Node Version

In the workflow JSON, check:
```json
{
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.4  ← Should be 2.x or higher
}
```

If lower, may need to update n8n.

### Check 3: Data Actually Exists

Add a temporary Code node after "Parse Architecture":
```javascript
console.log('Dependencies:', $json.architecture.dependencies);
console.log('Type:', typeof $json.architecture.dependencies);
console.log('Is Array:', Array.isArray($json.architecture.dependencies));

return { json: $input.item.json };
```

Should show:
```
Dependencies: [ { name: 'fastapi', version: '...' } ]
Type: object
Is Array: true
```

---

## 💡 ALTERNATIVE: Use Code Node to Insert

If Postgres nodes keep failing, replace all Store nodes with a single Code node:

```javascript
// After "Parse Architecture" node
const projectId = $json.project_id;
const arch = $json.architecture;

// Import pg client (if available in n8n)
const { Client } = require('pg');
const client = new Client({
  host: 'foundry_db',
  database: 'foundry',
  user: 'foundry',
  password: process.env.POSTGRES_PASSWORD || 'foundry',
  port: 5432,
});

await client.connect();

try {
  // Insert all blueprints
  await client.query(
    'INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version) VALUES ($1, $2, $3, $4)',
    [projectId, 'file_tree', arch.file_tree, 1]
  );
  
  await client.query(
    'INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version) VALUES ($1, $2, $3, $4)',
    [projectId, 'architecture', arch.architecture, 1]
  );
  
  await client.query(
    'INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version) VALUES ($1, $2, $3, $4)',
    [projectId, 'dependencies', arch.dependencies, 1]
  );
  
  await client.query(
    'INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version) VALUES ($1, $2, $3, $4)',
    [projectId, 'implementation_plan', arch.implementation_order, 1]
  );
  
  // Update project status
  await client.query(
    'UPDATE foundry_projects SET status = $1, updated_at = NOW() WHERE id = $2',
    ['phase2_complete', projectId]
  );
  
  return { json: { success: true, project_id: projectId } };
} finally {
  await client.end();
}
```

---

## ✅ SUMMARY

**Most common fix:**
1. Remove `JSON.stringify()` from all "Store" node content fields
2. Change content field type from "String" to "JSON"
3. Save workflow and re-execute

**If that doesn't work:**
1. Run `./fix_phase2_db.sh` to verify database schema
2. Check Postgres logs: `docker logs foundry_db --tail 50`
3. Use manual SQL inserts as backup

**You're very close!** This is a data type mismatch, not a fundamental workflow issue.

🏭 **"DEBUG WITH PRECISION, FIX WITH CONFIDENCE"**
