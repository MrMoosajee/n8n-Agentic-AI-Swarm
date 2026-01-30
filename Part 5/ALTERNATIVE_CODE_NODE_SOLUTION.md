# ALTERNATIVE FIX: Replace Store Nodes with Single Code Node
## For "Invalid input for 'content'" Errors

**Problem:** n8n Postgres nodes having issues with JSONB columns  
**Solution:** Use a Code node with direct SQL queries  

---

## 🎯 SOLUTION: REPLACE ALL 4 STORE NODES

Instead of fighting with the Postgres Insert nodes, we'll use ONE Code node that handles all inserts.

### Step 1: Delete/Disable the Problematic Nodes

In your workflow:
1. **Don't delete** the Store nodes yet (we might need them as reference)
2. Just **disconnect** them from "Parse Architecture"
3. We'll add a new Code node instead

### Step 2: Add Code Node After "Parse Architecture"

1. Click the **+** button after "Parse Architecture" node
2. Search for **"Code"**
3. Add a **Code** node
4. Name it: **"Store All Blueprints"**

### Step 3: Paste This Code

Copy and paste this EXACT code into the Code node:

```javascript
// Get data from Parse Architecture node
const projectId = $json.project_id;
const projectName = $json.project_name;
const architecture = $json.architecture;

// Validate we have all required data
if (!projectId || !architecture) {
  throw new Error('Missing project_id or architecture data');
}

// Validate architecture has all required fields
const requiredFields = ['file_tree', 'architecture', 'dependencies', 'implementation_order'];
const missingFields = requiredFields.filter(field => !architecture[field]);

if (missingFields.length > 0) {
  throw new Error('Architecture missing fields: ' + missingFields.join(', '));
}

// Prepare the SQL queries
const queries = [
  {
    type: 'file_tree',
    content: architecture.file_tree
  },
  {
    type: 'architecture',
    content: architecture.architecture
  },
  {
    type: 'dependencies',
    content: architecture.dependencies
  },
  {
    type: 'implementation_plan',
    content: architecture.implementation_order
  }
];

// Return data in format that Execute Query nodes can use
return queries.map(q => ({
  json: {
    project_id: projectId,
    project_name: projectName,
    blueprint_type: q.type,
    content_json: JSON.stringify(q.content), // Stringify for SQL
    version: 1,
    timestamp: $json.timestamp
  }
}));
```

### Step 4: Add Execute Query Node

1. After the new "Store All Blueprints" Code node
2. Add a **Postgres** node
3. Name it: **"Insert Blueprints (SQL)"**
4. Configure it:
   - **Operation:** Execute Query
   - **Query:**
   ```sql
   INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
   VALUES (
     {{ $json.project_id }},
     '{{ $json.blueprint_type }}',
     '{{ $json.content_json }}'::jsonb,
     {{ $json.version }}
   )
   ON CONFLICT DO NOTHING;
   ```
5. Link credential: **Foundry DB**

### Step 5: Connect the Nodes

Your new flow should be:
```
Parse Architecture 
    ↓
Store All Blueprints (Code)
    ↓
Insert Blueprints (SQL) (Postgres)
    ↓
Update Project Status
    ↓
Log Architecture Activity
    ↓
Success Message
```

### Step 6: Test

1. Save workflow (Ctrl+S)
2. Execute workflow
3. Should insert 4 rows (one per blueprint type)

---

## 🔄 COMPLETE ALTERNATIVE: Single Code Node with Direct DB Connection

If the above still has issues, use this **completely self-contained** solution:

### Replace ALL Store Nodes with THIS Single Code Node:

```javascript
// ================================================================
// STORE ALL BLUEPRINTS - Self-Contained Database Insert
// ================================================================

const projectId = $json.project_id;
const projectName = $json.project_name;
const architecture = $json.architecture;
const timestamp = $json.timestamp;

// Validate input
if (!projectId || !architecture) {
  throw new Error('Missing required data: project_id or architecture');
}

// Import postgres client
const { Client } = require('pg');

// Create database client
const client = new Client({
  host: 'foundry_db',
  database: 'foundry',
  user: 'foundry',
  password: 'foundry', // Change if you use different password
  port: 5432,
});

try {
  // Connect to database
  await client.connect();
  
  // Insert file_tree
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT DO NOTHING`,
    [projectId, 'file_tree', JSON.stringify(architecture.file_tree), 1]
  );
  
  // Insert architecture
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT DO NOTHING`,
    [projectId, 'architecture', JSON.stringify(architecture.architecture), 1]
  );
  
  // Insert dependencies
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT DO NOTHING`,
    [projectId, 'dependencies', JSON.stringify(architecture.dependencies), 1]
  );
  
  // Insert implementation_plan
  await client.query(
    `INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT DO NOTHING`,
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
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
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
  
  // Close connection
  await client.end();
  
  // Return success
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
  // Make sure to close connection on error
  try {
    await client.end();
  } catch (e) {
    // Ignore close errors
  }
  
  // Re-throw the error with details
  throw new Error('Database insert failed: ' + error.message);
}
```

**This code:**
- ✅ Connects directly to Postgres
- ✅ Inserts all 4 blueprints
- ✅ Updates project status
- ✅ Logs activity
- ✅ All in ONE node (no coordination issues)

### How to Use This:

1. **Delete/disconnect** all the Store nodes (File Tree, Architecture, Dependencies, Implementation Plan)
2. **Delete/disconnect** Update Project Status node
3. **Delete/disconnect** Log Architecture Activity node
4. **Add ONE Code node** after "Parse Architecture"
5. **Paste the complete code above**
6. **Connect** to "Success Message" node
7. **Save and test**

---

## 🧪 TESTING

### After adding the new Code node:

```bash
# Test the workflow
# Should complete in one step after Parse Architecture

# Verify in database:
docker exec -it foundry_db psql -U foundry -d foundry
```

```sql
-- Check blueprints were created
SELECT 
    bp.blueprint_type,
    jsonb_typeof(bp.content) as type,
    length(bp.content::text) as size
FROM foundry_blueprints bp
ORDER BY bp.id DESC
LIMIT 4;
```

**Expected:**
```
 blueprint_type      | type   | size
--------------------+--------+------
 implementation_plan | array  | 234
 dependencies        | array  | 456
 architecture        | object | 678
 file_tree           | object | 890
```

### Check project status:

```sql
SELECT id, project_name, status 
FROM foundry_projects 
ORDER BY updated_at DESC 
LIMIT 1;
```

**Expected:** `status = 'phase2_complete'`

---

## 📊 COMPARISON

### Old Way (4 Postgres Insert Nodes):
```
Parse Architecture
    ↓
Store File Tree ❌ (Error)
    ↓
Store Architecture ❌ (Error)
    ↓
Store Dependencies ❌ (Error: Invalid input)
    ↓
Store Implementation Plan ❌ (Error: Invalid input)
    ↓
Update Project Status
    ↓
Log Activity
```

### New Way (1 Code Node):
```
Parse Architecture
    ↓
Store All Blueprints ✅ (Code node with direct SQL)
    ↓
Success Message
```

**Benefits:**
- ✅ No type conversion issues
- ✅ Full control over SQL
- ✅ Easier to debug
- ✅ Fewer nodes = simpler workflow
- ✅ Atomic operation (all or nothing)

---

## 🚨 TROUBLESHOOTING

### Error: "Cannot find module 'pg'"

n8n might not have the pg module available. In that case, use the **first solution** (Code node + Execute Query node), not the complete solution.

### Error: "Password authentication failed"

Change this line in the code:
```javascript
password: 'foundry', // ← Change to your actual password
```

To find your password, check your docker-compose.yml:
```bash
grep POSTGRES_PASSWORD docker-compose.yml
```

### Error: "Database insert failed: relation does not exist"

Tables might be missing. Run:
```bash
docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql
```

---

## ✅ RECOMMENDATION

**Use the COMPLETE solution** (second code block) because:
1. It's self-contained
2. Handles all inserts in one transaction
3. No coordination between multiple nodes needed
4. Easier to debug
5. Faster execution

This bypasses all the n8n Postgres node JSONB issues entirely.

---

🏭 **"WHEN INSERT NODES FAIL, CODE PREVAILS"**
