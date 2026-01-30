# PHASE 2 HOTFIX - Node Reference Syntax
## Critical Update for Log Architecture Activity Node

**Issue:** Original workflow used incorrect syntax for referencing upstream nodes  
**Impact:** Log Architecture Activity node fails to capture correct project_id  
**Status:** FIXED in updated workflow JSON  
**Date:** 2026-01-28  

---

## 🚨 WHO NEEDS THIS FIX?

**If you already imported Phase 2 workflow BEFORE this update:**
- Check if "Log Architecture Activity" node shows errors
- Or if agent logs have NULL project_id values

**If you're importing Phase 2 for the FIRST time:**
- Use the updated `foundry_phase2_architecture_workflow.json`
- This fix is already included ✅

---

## 🔧 THE FIX

### Problem

**Original (INCORRECT):**
```json
{
  "project_id": "={{ $json.project_id }}",
  "input_data": "={{ JSON.stringify({ project: $json.project_name }) }}"
}
```

**Issue:** 
- `$json` references the CURRENT node's input
- But after the "Update Project Status" node, `$json` no longer contains project details
- Results in NULL or undefined values

### Solution

**Corrected (CORRECT):**
```json
{
  "project_id": "={{ $node[\"Parse Architecture\"].json.project_id }}",
  "input_data": "={{ JSON.stringify({ project: $node[\"Parse Architecture\"].json.project_name }) }}"
}
```

**Why this works:**
- `$node["Node Name"]` explicitly references a specific upstream node
- "Parse Architecture" node contains all project data we need
- Data persists regardless of workflow position

---

## 📝 MANUAL FIX (If Already Imported)

### Step 1: Open Phase 2 Workflow in n8n

1. Go to: http://localhost:5678
2. Open: "Foundry Phase 2: Architecture Generation"
3. Click: **"Log Architecture Activity"** node

### Step 2: Update Node Configuration

In the node's right panel:

**For "project_id" field:**
- Current value: `{{ $json.project_id }}`
- **Change to:** `{{ $node["Parse Architecture"].json.project_id }}`

**For "input_data" field:**
- Current value: `{{ JSON.stringify({ project: $json.project_name }) }}`
- **Change to:** `{{ JSON.stringify({ project: $node["Parse Architecture"].json.project_name }) }}`

**For "output_data" field (optional enhancement):**
- Current: `{{ JSON.stringify({ blueprints_created: 4 }) }}`
- **Improve to:** `{{ JSON.stringify({ blueprints_created: 4, timestamp: $node["Parse Architecture"].json.timestamp }) }}`

### Step 3: Save Workflow

- Click **Save** (Ctrl+S or Cmd+S)
- Workflow will update immediately

### Step 4: Test the Fix

Execute the workflow and verify:

```sql
-- Check that project_id is now populated correctly
SELECT 
  id,
  project_id,
  agent_role,
  action,
  success,
  created_at
FROM foundry_agent_log
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:** `project_id` column has valid integer values (not NULL)

---

## 🔍 ALTERNATIVE FIX (Re-import)

If manual editing is tedious:

1. **Delete old Phase 2 workflow** in n8n
2. **Re-import** the updated `foundry_phase2_architecture_workflow.json`
3. **Re-link credentials** (Gemini + Postgres)
4. **Activate** workflow

**Note:** This is cleaner but requires re-linking all credentials

---

## 📊 VERIFICATION

### Test 1: Dry Run
```sql
-- Before fix: Check if any logs have NULL project_id
SELECT COUNT(*) 
FROM foundry_agent_log 
WHERE project_id IS NULL;

-- Should return 0 after fix
```

### Test 2: Execute Workflow

1. Execute Phase 2 workflow
2. Check latest log entry:

```sql
SELECT * 
FROM foundry_agent_log 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected values:**
- `project_id`: Valid integer (e.g., 1, 2, 3)
- `agent_role`: "architect"
- `action`: "generate_blueprints"
- `input_data`: `{"project": "Project Name"}`
- `output_data`: `{"blueprints_created": 4, "timestamp": "2026-..."}`
- `model_used`: "gemini-1.5-pro"
- `success`: true

---

## 🎓 LEARNING: n8n Expression Syntax

### Key Concepts

**`$json`** - Current node's input
```javascript
// Use when: The data you need is coming directly from previous node
// Example: In a "Set" node that processes data from immediate predecessor
"value": "={{ $json.fieldName }}"
```

**`$node["Node Name"]`** - Specific upstream node
```javascript
// Use when: You need data from a specific earlier node (not just previous)
// Example: Need project data after several intermediate nodes
"value": "={{ $node[\"Fetch Next Project\"].json.id }}"
```

**`$("Node Name")`** - Alternative syntax (shorter)
```javascript
// Same as $node["Node Name"] but cleaner
"value": "={{ $(\"Fetch Next Project\").item.json.id }}"
```

### Best Practices

1. **Use explicit node references** when data needs to persist across multiple nodes
2. **Use $json** only for immediate predecessor's output
3. **Test expressions** with Execute Node before saving workflow
4. **Log intermediate values** during development:
   ```javascript
   console.log('Debug:', $node["SomeNode"].json);
   ```

---

## 🐛 RELATED ISSUES TO CHECK

If you encounter similar problems in other nodes:

### "Success Message" Node
**Check:** Does it reference correct project data?
```json
{
  "message": "={{ \"Phase 2 Complete: \" + $node[\"Parse Architecture\"].json.project_name }}"
}
```

### "Update Project Status" Node
**Check:** Does the SQL query use correct project_id?
```sql
UPDATE foundry_projects
SET status = 'phase2_complete', updated_at = NOW()
WHERE id = {{ $node["Parse Architecture"].json.project_id }};
```

**Current:** Uses `{{ $json.project_id }}` ✅ (This is CORRECT because it runs immediately after Parse Architecture)

---

## 📞 SUPPORT

If the fix doesn't work:

1. **Check node connections:**
   ```
   Parse Architecture → Store nodes → Update Status → Log Activity
   ```
   Ensure "Log Activity" receives input from "Update Status"

2. **Check Parse Architecture output:**
   ```javascript
   // In Parse Architecture node, verify return includes:
   {
     project_id: previousData.project_id,
     project_name: previousData.project_name,
     // ... other fields
   }
   ```

3. **Debug with Code node:**
   Add temporary Code node before Log Activity:
   ```javascript
   console.log('Available data:', $input.item.json);
   console.log('Parse Architecture data:', $node["Parse Architecture"].json);
   return { json: $input.item.json };
   ```

---

## ✅ CHECKLIST

After applying fix:

- [ ] Updated "Log Architecture Activity" node expressions
- [ ] Saved workflow
- [ ] Executed test run
- [ ] Verified SQL: No NULL project_id values
- [ ] All 4 blueprints created successfully
- [ ] Agent log shows correct project details

---

**Updated:** 2026-01-28  
**Version:** Phase 2 v1.1  
**Status:** Hotfix Applied ✅

🏭 **"PRECISION IN SYNTAX, EXCELLENCE IN EXECUTION"**
