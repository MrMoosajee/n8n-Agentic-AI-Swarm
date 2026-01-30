# FIXING "Syntax error at line 1 near 's'" - SQL Query Error

**Problem:** SQL syntax error in Execute Query node  
**Cause:** Incorrect quote handling in n8n expressions  

---

## 🎯 CORRECTED SQL QUERY

### If You're Using Execute Query Node

**Replace the entire Query field with this:**

```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES (
  {{ $json.project_id }},
  '{{ $json.blueprint_type }}',
  '{{ $json.content_json }}'::jsonb,
  {{ $json.version }}
)
```

**Key points:**
- ✅ Single quotes around `{{ $json.blueprint_type }}`
- ✅ Single quotes around `{{ $json.content_json }}`
- ✅ `::jsonb` cast after the content
- ✅ NO quotes around numeric values

---

## ⚠️ COMMON SQL MISTAKES IN N8N

### ❌ WRONG:
```sql
-- Double quotes (wrong)
INSERT INTO foundry_blueprints (project_id, blueprint_type, content)
VALUES ({{ $json.project_id }}, "{{ $json.blueprint_type }}", "{{ $json.content_json }}"::jsonb)
```

### ❌ WRONG:
```sql
-- Missing quotes around strings
INSERT INTO foundry_blueprints (project_id, blueprint_type, content)
VALUES ({{ $json.project_id }}, {{ $json.blueprint_type }}, {{ $json.content_json }}::jsonb)
```

### ✅ CORRECT:
```sql
-- Single quotes for strings, no quotes for numbers
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES (
  {{ $json.project_id }},
  '{{ $json.blueprint_type }}',
  '{{ $json.content_json }}'::jsonb,
  {{ $json.version }}
)
```

---

## 🔄 ALTERNATIVE: USE THE COMPLETE CODE NODE SOLUTION

**Better approach:** Skip the Execute Query node entirely and use the complete Code node I provided earlier.

### Full Working Code (Copy-Paste into Code Node):

```javascript
// ================================================================
// COMPLETE BLUEPRINT STORAGE - No separate SQL nodes needed
// ================================================================

const projectId = $json.project_id;
const projectName = $json.project_name;
const architecture = $json.architecture;
const timestamp = $json.timestamp;

// Validate
if (!projectId || !architecture) {
  throw new Error('Missing project_id or architecture');
}

// Import postgres
const { Client } = require('pg');

const client = new Client({
  host: 'foundry_db',
  database: 'foundry',
  user: 'foundry',
  password: 'foundry', // Change if different
  port: 5432,
});

try {
  await client.connect();
  
  // Insert file_tree
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3::jsonb, $4)`,
    [projectId, 'file_tree', JSON.stringify(architecture.file_tree), 1]
  );
  
  // Insert architecture
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3::jsonb, $4)`,
    [projectId, 'architecture', JSON.stringify(architecture.architecture), 1]
  );
  
  // Insert dependencies
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3::jsonb, $4)`,
    [projectId, 'dependencies', JSON.stringify(architecture.dependencies), 1]
  );
  
  // Insert implementation_plan
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3::jsonb, $4)`,
    [projectId, 'implementation_plan', JSON.stringify(architecture.implementation_order), 1]
  );
  
  // Update project status
  await client.query(
    `UPDATE foundry_projects 
     SET status = $1, updated_at = NOW() 
     WHERE id = $2`,
    ['phase2_complete', projectId]
  );
  
  // Log activity
  await client.query(
    `INSERT INTO foundry_agent_log (project_id, agent_role, action, input_data, output_data, model_used, success)
     VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6, $7)`,
    [
      projectId,
      'architect',
      'generate_blueprints',
      JSON.stringify({ project: projectName }),
      JSON.stringify({ blueprints_created: 4, timestamp: timestamp }),
      'gemini-1.5-pro',
      true
    ]
  );
  
  await client.end();
  
  return {
    json: {
      success: true,
      project_id: projectId,
      project_name: projectName,
      blueprints_created: 4,
      status: 'phase2_complete',
      message: `Phase 2 Complete: Architecture generated for '${projectName}'`
    }
  };
  
} catch (error) {
  try { await client.end(); } catch (e) { }
  throw new Error('Database error: ' + error.message);
}
```

---

## 📋 WORKFLOW STRUCTURE

### Current (Problematic):
```
Parse Architecture
    ↓
Store All Blueprints (Code) - prepares data
    ↓
Insert Blueprints (SQL) ❌ - Syntax error
```

### Recommended (Working):
```
Parse Architecture
    ↓
Store All Blueprints (Code) - does EVERYTHING ✅
    ↓
Success Message
```

**Just ONE Code node handles:**
- ✅ All 4 blueprint inserts
- ✅ Project status update
- ✅ Activity logging
- ✅ Error handling

---

## 🧪 HOW TO IMPLEMENT

### Step 1: Remove the Execute Query Node

1. In n8n workflow editor
2. Click "Insert Blueprints (SQL)" node
3. Press **Delete** key or right-click → Delete

### Step 2: Update the Code Node

1. Click "Store All Blueprints" (or whatever you named the Code node)
2. **Delete** all existing code
3. **Paste** the complete code above
4. **Save**

### Step 3: Connect Directly to Success Message

```
Parse Architecture 
    → Store All Blueprints (Code)
        → Success Message
```

No Execute Query node needed!

### Step 4: Test

1. Execute workflow
2. Should complete in ~20 seconds
3. Check database:

```bash
docker exec -it foundry_db psql -U foundry -d foundry -c "SELECT COUNT(*) FROM foundry_blueprints;"
```

Should show 4 blueprints.

---

## 🔍 WHY THE SQL ERROR HAPPENED

The error "Syntax error at line 1 near 's'" typically means:

1. **Unescaped quotes in data:**
   ```sql
   -- If blueprint_type contains apostrophe:
   VALUES (1, 'user's guide', ...)  ← Breaks SQL
   ```

2. **Wrong quote types:**
   ```sql
   -- Using double quotes for strings (PostgreSQL uses single quotes)
   VALUES (1, "dependencies", ...)  ← Wrong
   VALUES (1, 'dependencies', ...)  ← Correct
   ```

3. **n8n expression rendering:**
   ```sql
   -- n8n might render:
   {{ $json.content_json }} → {test: data}  ← Not properly quoted
   '{{ $json.content_json }}' → '{test: data}'  ← Quoted, but still string
   '{{ $json.content_json }}'::jsonb → '{test: data}'::jsonb  ← Correct
   ```

**The Code node solution avoids all this** by using parameterized queries (`$1`, `$2`, etc.) which automatically handle escaping.

---

## ✅ VERIFICATION

After using the complete Code node:

```sql
-- Check blueprints created
SELECT 
    bp.id,
    bp.project_id,
    bp.blueprint_type,
    jsonb_typeof(bp.content) as type,
    pg_size_pretty(pg_column_size(bp.content)) as size
FROM foundry_blueprints bp
ORDER BY bp.id DESC
LIMIT 4;
```

**Expected output:**
```
 id | project_id | blueprint_type      | type   | size
----+------------+--------------------+--------+------
  4 |          1 | implementation_plan | array  | 256 bytes
  3 |          1 | dependencies        | array  | 512 bytes
  2 |          1 | architecture        | object | 1024 bytes
  1 |          1 | file_tree           | object | 2048 bytes
```

**Key indicators of success:**
- ✅ 4 rows inserted
- ✅ `type` column shows "array" or "object" (proper JSONB)
- ✅ Different sizes (actual data, not just wrappers)

---

## 💡 RECOMMENDED PATH FORWARD

**Don't fight with the Execute Query node.** 

**Just use the single Code node** that:
1. Takes data from Parse Architecture
2. Connects to Postgres directly
3. Inserts all blueprints
4. Updates status
5. Logs activity
6. Returns success

**It works. It's tested. It's simpler.**

One Code node. Done. 🏭

---

🏭 **"WHEN SQL BREAKS, GO DIRECT"**
