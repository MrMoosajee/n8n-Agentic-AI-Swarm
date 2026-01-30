# FIXING "UPDATE foundry_projects" - Undefined project_id

**Problem:** `{{ $item(0).json.project_id }}` returns undefined  
**Cause:** Incorrect way to reference data from previous nodes  
**Solution:** Use proper n8n expression syntax  

---

## 🎯 QUICK FIX

In your "Update Project Status" node, **replace the query with ONE of these:**

### Option 1: Reference the Code Node Directly

```sql
UPDATE foundry_projects 
SET status = 'phase2_complete', updated_at = NOW() 
WHERE id = {{ $node["Parse Architecture"].json.project_id }}
```

**Why this works:**
- References the "Parse Architecture" node by name
- Gets project_id from that node's output
- Works regardless of how many items were processed

---

### Option 2: Use Current Item (if only 1 item flows through)

```sql
UPDATE foundry_projects 
SET status = 'phase2_complete', updated_at = NOW() 
WHERE id = {{ $json.pid }}
```

**Note:** This only works if your Code node returns a SINGLE merged item, not 4 separate items.

---

### Option 3: Add a Merge Node First

**Better workflow structure:**

```
Parse Architecture
    ↓
Code (outputs 4 items)
    ↓
Execute Query (runs 4x, inserts all blueprints)
    ↓
Code: Get Project ID  ← ADD THIS
    ↓
Update Status
```

**Code: Get Project ID** (new Code node):
```javascript
// Get project_id from any item (they're all the same)
const projectId = $input.all()[0].json.pid;

return {
  json: {
    project_id: projectId
  }
};
```

**Update Status Query:**
```sql
UPDATE foundry_projects 
SET status = 'phase2_complete', updated_at = NOW() 
WHERE id = {{ $json.project_id }}
```

---

## ✅ RECOMMENDED APPROACH

The **simplest solution** is to use **Option 1** - reference "Parse Architecture" directly:

### Step-by-Step:

1. **Click** "Update Project Status" node
2. **Find** the Query field
3. **Replace** with:
   ```sql
   UPDATE foundry_projects 
   SET status = 'phase2_complete', updated_at = NOW() 
   WHERE id = {{ $node["Parse Architecture"].json.project_id }}
   ```
4. **Save** (Ctrl+S)

**This works because:**
- "Parse Architecture" node always has `project_id` in its output
- It's accessible from any downstream node
- No matter how many items flow through, project_id is the same

---

## 🔍 UNDERSTANDING THE ISSUE

### Why `$item(0)` Doesn't Work Here

**What n8n does:**
1. Code node outputs 4 items (array)
2. Execute Query runs 4 times (once per item)
3. After Execute Query, you might have 4 outputs
4. `$item(0)` tries to get the first item, but context is wrong

**What you need:**
- Just reference the original source of project_id
- Which is "Parse Architecture" node

### Data Flow Visualization

```
Parse Architecture
{
  project_id: 1,
  project_name: "Test",
  architecture: { ... }
}
    ↓
Code: Prepare 4 Items
[
  { pid: 1, type: 'file_tree', data: {...} },
  { pid: 1, type: 'architecture', data: {...} },
  { pid: 1, type: 'dependencies', data: {...} },
  { pid: 1, type: 'implementation_plan', data: {...} }
]
    ↓
Execute Query (runs 4x)
[
  { insert_result_1 },
  { insert_result_2 },
  { insert_result_3 },
  { insert_result_4 }
]
    ↓
Update Status ← Need project_id here
How to get it? → {{ $node["Parse Architecture"].json.project_id }}
```

---

## 🧪 TEST THE FIX

After updating the query:

1. **Execute** the "Update Project Status" node alone
2. Should show: `WHERE id = 1` (or whatever your actual project_id is)
3. Should execute successfully
4. Check database:

```sql
SELECT id, project_name, status, updated_at 
FROM foundry_projects 
ORDER BY updated_at DESC 
LIMIT 1;
```

**Expected:** Status = `phase2_complete`

---

## 📋 COMPLETE WORKFLOW CHECKLIST

After this fix, your Phase 2 workflow should be:

- [x] **Schedule Trigger** - runs every 5 min
- [x] **Fetch Next Project** - SQL query
- [x] **Project Found?** - IF node
- [x] **Build Architect Prompt** - Code node
- [x] **Architect: Gemini Pro** - HTTP Request
- [x] **Parse Architecture** - Code node (✅ working)
- [x] **Prepare Blueprints** - Code node (outputs 4 items)
- [x] **Execute Query (Insert)** - Postgres (runs 4x)
- [x] **Update Project Status** - Postgres (fix with `$node["Parse Architecture"].json.project_id`)
- [ ] **Log Architecture Activity** - Postgres (might need similar fix)
- [x] **Success Message** - Set node

---

## 🔧 FIX "Log Architecture Activity" TOO

The Log node will have the same issue. Update it:

**Query:**
```sql
INSERT INTO foundry_agent_log (project_id, agent_role, action, input_data, output_data, model_used, success)
VALUES (
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
- Parameter 1: `{{ JSON.stringify({ project: $node["Parse Architecture"].json.project_name }) }}`
- Parameter 2: `{{ JSON.stringify({ blueprints_created: 4, timestamp: $node["Parse Architecture"].json.timestamp }) }}`

---

## ✅ FINAL VERIFICATION

After fixing both Update and Log nodes:

```bash
# Run full workflow, then check:
docker exec -it foundry_db psql -U foundry -d foundry
```

```sql
-- Check blueprints
SELECT COUNT(*) FROM foundry_blueprints WHERE project_id = 1;
-- Should return: 4

-- Check status
SELECT status FROM foundry_projects WHERE id = 1;
-- Should return: phase2_complete

-- Check logs
SELECT * FROM foundry_agent_log WHERE agent_role = 'architect' ORDER BY created_at DESC LIMIT 1;
-- Should have 1 row with project_id = 1
```

---

## 💡 PRO TIP: Add Execute Once Node

If you want to ensure Update and Log only run once (not 4 times), add a **"Limit"** node:

```
Execute Query (runs 4x)
    ↓
Limit (only 1 item) ← Add this
    ↓
Update Status (runs 1x)
    ↓
Log Activity (runs 1x)
```

**Limit node configuration:**
- Max Items: 1
- Keep: First Item

This ensures Update and Log only execute once, even though Execute Query ran 4 times.

---

🏭 **"REFERENCE THE SOURCE, NOT THE STREAM"**
