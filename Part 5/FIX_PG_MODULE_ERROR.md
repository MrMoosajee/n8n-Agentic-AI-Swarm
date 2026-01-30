# FIX: "Module 'pg' is disallowed" - Alternative Solution

**Problem:** Can't use `pg` module in n8n Code nodes  
**Solution:** Use Execute Query with proper data preparation  

---

## 🎯 WORKING SOLUTION (No External Modules)

### Step 1: Prepare Data with Code Node

**Click your Code node after "Parse Architecture"**  
**Replace with this code (NO pg module):**

```javascript
// Prepare data for SQL inserts - NO external modules needed
const projectId = $json.project_id;
const projectName = $json.project_name;
const architecture = $json.architecture;
const timestamp = $json.timestamp;

// Validate
if (!projectId || !architecture) {
  throw new Error('Missing required data');
}

// Create 4 items, one for each blueprint type
const blueprints = [
  {
    project_id: projectId,
    blueprint_type: 'file_tree',
    content: architecture.file_tree,
    version: 1
  },
  {
    project_id: projectId,
    blueprint_type: 'architecture',
    content: architecture.architecture,
    version: 1
  },
  {
    project_id: projectId,
    blueprint_type: 'dependencies',
    content: architecture.dependencies,
    version: 1
  },
  {
    project_id: projectId,
    blueprint_type: 'implementation_plan',
    content: architecture.implementation_order,
    version: 1
  }
];

// Return as array for n8n to process
return blueprints.map(bp => ({
  json: bp
}));
```

### Step 2: Add Postgres Execute Query Node

**After the Code node, add Postgres node:**

1. **Operation:** Execute Query
2. **Query:** (use this EXACT format)

```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES (
  {{ $json.project_id }},
  '{{ $json.blueprint_type }}',
  $1::jsonb,
  {{ $json.version }}
)
```

3. **Query Parameters:** Click "Add Parameter"
   - **Parameter 1:** `{{ JSON.stringify($json.content) }}`

4. **Credential:** Foundry DB

### Step 3: Add Another Postgres Node (Update Status)

**After the Insert node:**

1. **Operation:** Execute Query
2. **Query:**

```sql
UPDATE foundry_projects 
SET status = 'phase2_complete', updated_at = NOW() 
WHERE id = {{ $item(0).json.project_id }}
```

3. **Credential:** Foundry DB

---

## 🔄 ALTERNATIVE: Use Loop Over Items

If the above still has issues, use this approach:

### Complete Workflow Structure:

```
Parse Architecture
    ↓
Prepare Blueprints (Code) - creates 4 items
    ↓
[Loop starts - n8n processes each item]
    ↓
Insert Single Blueprint (Postgres Execute Query)
    ↓
[Loop ends]
    ↓
Update Status (Postgres Execute Query)
    ↓
Success Message
```

### Code for "Prepare Blueprints":

```javascript
const projectId = $json.project_id;
const projectName = $json.project_name;
const architecture = $json.architecture;

// Return 4 separate items for n8n to loop over
return [
  { json: { project_id: projectId, project_name: projectName, type: 'file_tree', data: architecture.file_tree, version: 1 } },
  { json: { project_id: projectId, project_name: projectName, type: 'architecture', data: architecture.architecture, version: 1 } },
  { json: { project_id: projectId, project_name: projectName, type: 'dependencies', data: architecture.dependencies, version: 1 } },
  { json: { project_id: projectId, project_name: projectName, type: 'implementation_plan', data: architecture.implementation_order, version: 1 } }
];
```

### SQL for "Insert Single Blueprint":

```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES (
  {{ $json.project_id }},
  '{{ $json.type }}',
  $1::jsonb,
  {{ $json.version }}
)
```

**Query Parameters:**
- Parameter 1: `{{ JSON.stringify($json.data) }}`

---

## 🎨 SIMPLEST SOLUTION: Use Built-in Postgres Insert (Fixed)

Actually, let's go back to basics and fix the original Insert nodes properly.

### For EACH Store Node (File Tree, Architecture, Dependencies, Implementation):

1. **Operation:** Insert
2. **Table:** foundry_blueprints
3. **Columns:** Map these fields:

| Column Name | Type | Value (Expression) |
|-------------|------|-------------------|
| project_id | Number | `{{ $json.project_id }}` |
| blueprint_type | String | `file_tree` (or `architecture`, `dependencies`, `implementation_plan`) |
| content | Expression | `{{ $json.architecture.file_tree }}` (change per node) |
| version | Number | `1` |

**CRITICAL for content field:**
- Don't select "JSON" or "String" type
- Select **"Expression"**
- In the expression, just reference the data directly: `{{ $json.architecture.file_tree }}`

### Step-by-Step for "Store Dependencies" Node:

1. Click node
2. Operation: Insert
3. Table: foundry_blueprints
4. Columns section - click "Add Column"
5. Map these:
   ```
   project_id:      Number      {{ $json.project_id }}
   blueprint_type:  String      dependencies
   content:         Expression  {{ $json.architecture.dependencies }}
   version:         Number      1
   ```

**The key is using "Expression" type for content, not "JSON" or "String"**

---

## 🧪 TEST THIS APPROACH

### After setting up nodes:

1. Execute "Parse Architecture" alone first - verify output
2. Then execute "Store Dependencies" alone - should work
3. If works, apply same config to other 3 Store nodes
4. Execute full workflow

---

## 📊 DEBUGGING

If still getting errors, check:

```bash
# Check database schema
docker exec foundry_db psql -U foundry -d foundry -c "\d foundry_blueprints"
```

Should show:
```
 content | jsonb | not null
```

If it shows `json` or `text`, fix with:

```sql
ALTER TABLE foundry_blueprints ALTER COLUMN content TYPE jsonb USING content::jsonb;
```

---

## ✅ RECOMMENDED: Prepare + Execute Query with Parameters

This is the most reliable approach in n8n:

### Workflow:
```
Parse Architecture
    ↓
Code: Prepare 4 Items
    ↓
Postgres: Execute Query (loops 4x automatically)
    ↓
Postgres: Update Status  
    ↓
Success
```

### Code Node:
```javascript
const projectId = $json.project_id;
const arch = $json.architecture;

return [
  { json: { pid: projectId, type: 'file_tree', data: arch.file_tree } },
  { json: { pid: projectId, type: 'architecture', data: arch.architecture } },
  { json: { pid: projectId, type: 'dependencies', data: arch.dependencies } },
  { json: { pid: projectId, type: 'implementation_plan', data: arch.implementation_order } }
];
```

### Execute Query Node:
```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES ({{ $json.pid }}, '{{ $json.type }}', $1::jsonb, 1)
```

**Query Parameters:**
- `{{ JSON.stringify($json.data) }}`

This will run 4 times (once per item) and insert all blueprints.

---

🏭 **"NO MODULES NEEDED, JUST SMART NODE CONFIGURATION"**
