# FIXING ALL STORE NODES - VISUAL GUIDE
## Now That Parse Architecture is Working

**Status:** ✅ Parse Architecture working  
**Next:** Fix the 4 Store nodes to save data correctly  

---

## 🎯 THE PROBLEM

Your Store nodes are currently configured like this (WRONG):

```
Content field:
  Type: String
  Value: {{ JSON.stringify($json.architecture.dependencies) }}
```

**Result:** Postgres receives a STRING like `"[{\"name\":\"fastapi\"}]"` instead of actual JSONB

---

## ✅ THE FIX (Do This for ALL 4 Store Nodes)

### Node 1: "Store File Tree"

**Click on the node**, then in right panel:

1. **Find:** Columns → content
2. **Change Type:** String → **JSON**
3. **Change Value:** 
   - **Remove:** `{{ JSON.stringify($json.architecture.file_tree) }}`
   - **Use:** `{{ $json.architecture.file_tree }}`
4. **Click Save**

**Visual Config:**
```
Column Mappings:
  project_id:      {{ $json.project_id }}          (Number)
  blueprint_type:  file_tree                       (String)
  content:         {{ $json.architecture.file_tree }}  (JSON) ← IMPORTANT!
  version:         1                                (Number)
```

---

### Node 2: "Store Architecture"

**Same process:**

1. Click node
2. Columns → content
3. **Type:** JSON (not String)
4. **Value:** `{{ $json.architecture.architecture }}`
5. Save

**Visual Config:**
```
Column Mappings:
  project_id:      {{ $json.project_id }}
  blueprint_type:  architecture
  content:         {{ $json.architecture.architecture }}  (JSON)
  version:         1
```

---

### Node 3: "Store Dependencies"

**This is the one showing the error in your screenshot:**

1. Click "Store Dependencies" node
2. Columns → content
3. **Type:** JSON
4. **Value:** `{{ $json.architecture.dependencies }}`
5. Save

**Visual Config:**
```
Column Mappings:
  project_id:      {{ $json.project_id }}
  blueprint_type:  dependencies
  content:         {{ $json.architecture.dependencies }}  (JSON)
  version:         1
```

---

### Node 4: "Store Implementation Plan"

**Last one:**

1. Click node
2. Columns → content
3. **Type:** JSON
4. **Value:** `{{ $json.architecture.implementation_order }}`
5. Save

**Visual Config:**
```
Column Mappings:
  project_id:      {{ $json.project_id }}
  blueprint_type:  implementation_plan
  content:         {{ $json.architecture.implementation_order }}  (JSON)
  version:         1
```

---

## 🖼️ VISUAL: HOW TO CHANGE TYPE IN N8N

When you click on a Store node, the right panel shows:

```
┌─────────────────────────────────────────┐
│ Parameters                              │
├─────────────────────────────────────────┤
│ Operation: Insert                       │
│ Table: foundry_blueprints               │
│                                         │
│ Columns:                                │
│ ┌─────────────────────────────────────┐ │
│ │ project_id                          │ │
│ │   ↓ Number                          │ │ ← Dropdown
│ │   {{ $json.project_id }}            │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ blueprint_type                      │ │
│ │   ↓ String                          │ │
│ │   dependencies                      │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ content                             │ │
│ │   ↓ String  ← CHANGE THIS TO "JSON" │ │ ← Click dropdown
│ │   {{ JSON.stringify(...) }}         │ │ ← Remove stringify
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ version                             │ │
│ │   ↓ Number                          │ │
│ │   1                                 │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Steps:**
1. Click the **dropdown** next to "content" (currently says "String")
2. Select **"JSON"** from the dropdown
3. In the value field, **remove `JSON.stringify(` and the closing `)`**
4. Leave just: `{{ $json.architecture.dependencies }}`

---

## 🧪 TEST AFTER FIXING

### Quick Test (Single Node)

1. Click "Store Dependencies" node (after fixing it)
2. Click "Execute Node" (play button on the node itself)
3. Should show **green checkmark** ✅
4. Check output panel - should say "1 row inserted"

### Full Workflow Test

1. Click "Execute Workflow" (big play button at bottom)
2. Wait for completion
3. **All nodes should be green** ✅

### Database Verification

```bash
docker exec -it foundry_db psql -U foundry -d foundry
```

```sql
-- Check latest blueprints
SELECT 
    bp.id,
    bp.project_id,
    bp.blueprint_type,
    jsonb_typeof(bp.content) as content_type,
    LENGTH(bp.content::text) as content_size
FROM foundry_blueprints bp
ORDER BY bp.id DESC
LIMIT 10;
```

**Expected output:**
```
 id | project_id | blueprint_type      | content_type | content_size
----+------------+--------------------+--------------+--------------
  4 |          1 | implementation_plan | array        |          245
  3 |          1 | dependencies        | array        |          389
  2 |          1 | architecture        | object       |          567
  1 |          1 | file_tree           | object       |          823
```

**Good signs:**
- ✅ content_type shows "object" or "array" (NOT "string")
- ✅ content_size varies (actual data, not just stringified wrapper)

**Bad signs:**
- ❌ content_type shows "string"
- ❌ All content_size values are similar
- ❌ Error: "column content is of type jsonb but expression is of type text"

---

## 📋 CHECKLIST

Before executing full workflow:

- [ ] **Store File Tree** - content type = JSON, value = `{{ $json.architecture.file_tree }}`
- [ ] **Store Architecture** - content type = JSON, value = `{{ $json.architecture.architecture }}`
- [ ] **Store Dependencies** - content type = JSON, value = `{{ $json.architecture.dependencies }}`
- [ ] **Store Implementation Plan** - content type = JSON, value = `{{ $json.architecture.implementation_order }}`
- [ ] **Saved workflow** (Ctrl+S)
- [ ] **Tested individual nodes** (all green)

---

## 🚨 IF ERRORS PERSIST

### Error: "Invalid input for 'content'"

**Cause:** Type is still String or value still has JSON.stringify()

**Fix:**
1. Double-check the dropdown shows **"JSON"** not "String"
2. Make sure value has NO `JSON.stringify(`
3. Try deleting and re-adding the content mapping

### Error: "Cannot insert NULL into column content"

**Cause:** The architecture object doesn't have that sub-field

**Debug:**
1. Click "Parse Architecture" node
2. Execute it
3. Check output has `architecture.dependencies` (or whatever field is failing)
4. If missing, Gemini didn't generate it - check Gemini prompt

### Error: "Column content is of type jsonb but expression is of type text"

**Cause:** n8n is still sending text instead of JSON

**Fix:**
1. In the Store node, click "Add Column" 
2. Remove old "content" mapping
3. Re-add: Column name = "content", Type = "JSON", Value = `{{ $json.architecture.XXX }}`

---

## 💡 ALTERNATIVE: Use Execute Query Instead

If the Insert operation keeps failing, try **Execute Query** mode:

1. Click Store node
2. Change **Operation** to "Execute Query"
3. Use this SQL:

**For Store Dependencies:**
```sql
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
VALUES (
  {{ $json.project_id }},
  'dependencies',
  {{ $json.architecture.dependencies }}::jsonb,
  1
);
```

This explicitly casts to JSONB and may work better.

---

## ✅ SUCCESS CRITERIA

You'll know it's working when:

1. ✅ All 4 Store nodes execute with green checkmarks
2. ✅ "Update Project Status" node executes
3. ✅ Database query shows 4 blueprints per project
4. ✅ `jsonb_typeof(content)` shows "object" or "array" (not "string")
5. ✅ You can query the JSONB data:
   ```sql
   SELECT content->'structure' FROM foundry_blueprints WHERE blueprint_type = 'file_tree';
   ```

---

## 🎯 AFTER ALL 4 NODES ARE FIXED

Once all Store nodes work:

1. **Full test:** Execute entire workflow start to finish
2. **Verify database:** Check all 4 blueprint types are stored
3. **Check project status:** Should update to 'phase2_complete'
4. **Ready for Phase 3!** 🎉

---

🏭 **"FIX THE TYPE, STORE WITH CONFIDENCE, BUILD WITH PRECISION"**
