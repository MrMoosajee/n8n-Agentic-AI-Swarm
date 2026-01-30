# N8N EXPRESSION SYNTAX - QUICK REFERENCE
## For Foundry Workflow Development

**Purpose:** Avoid common expression errors when building workflows  
**Applies to:** All Foundry phases (1, 2, 3, 4)  
**Last Updated:** 2026-01-28  

---

## 📚 CORE SYNTAX

### 1. Current Node Input: `$json`

**What it is:** Data from the **immediately preceding** node

**Use when:** Processing data that just arrived from previous node

**Example:**
```javascript
// In a "Set" node after HTTP Request
"value": "={{ $json.response.data }}"

// In a Code node
const userId = $json.user_id;
```

**Common Mistake:**
```javascript
// ❌ WRONG: Using $json several nodes later
Node 1 → Node 2 → Node 3 → Node 4
// In Node 4, $json only has Node 3's output, NOT Node 1's
```

---

### 2. Specific Node Reference: `$node["Name"]`

**What it is:** Data from **any upstream node** by name

**Use when:** You need data from a specific earlier node, not just previous one

**Example:**
```javascript
// Access project ID from "Fetch Next Project" node
"project_id": "={{ $node[\"Fetch Next Project\"].json.id }}"

// Access multiple fields
"project_name": "={{ $node[\"Parse Architecture\"].json.project_name }}"
```

**Important:** Node names must match exactly (case-sensitive, spaces included)

---

### 3. Alternative Syntax: `$("Name")`

**What it is:** Shorthand for `$node["Name"]`

**Use when:** Cleaner syntax preference (functionally identical)

**Example:**
```javascript
// Same as $node["Fetch Next Project"].json.id
"project_id": "={{ $(\"Fetch Next Project\").item.json.id }}"
```

**Note:** Uses `.item.json` instead of `.json` (minor difference)

---

## 🎯 COMMON PATTERNS

### Pattern 1: Insert Data from Earlier Node

**Scenario:** Store data in Postgres, referencing node from 3 steps back

```json
{
  "columns": {
    "value": {
      "project_id": "={{ $node[\"Fetch Next Project\"].json.id }}",
      "status": "={{ $node[\"Parse Results\"].json.status }}",
      "created_at": "={{ $now }}"
    }
  }
}
```

---

### Pattern 2: Combine Data from Multiple Nodes

**Scenario:** Merge outputs from different nodes

```javascript
// In Code node
const projectData = $node["Fetch Project"].json;
const architectureData = $node["Generate Architecture"].json;

return {
  json: {
    project_id: projectData.id,
    architecture: architectureData.blueprints,
    combined_at: new Date().toISOString()
  }
};
```

---

### Pattern 3: Conditional Logic Based on Earlier Node

**Scenario:** IF node checking data from specific node

```javascript
// In IF node
"conditions": {
  "leftValue": "={{ $node[\"API Request\"].json.status_code }}",
  "rightValue": "200",
  "operator": "equal"
}
```

---

### Pattern 4: SQL Query with Dynamic Values

**Scenario:** Postgres node with values from earlier nodes

```sql
UPDATE foundry_projects
SET status = 'phase2_complete',
    updated_at = NOW()
WHERE id = {{ $node["Parse Architecture"].json.project_id }};
```

**Important:** SQL queries use `{{ }}` without `=` prefix

---

### Pattern 5: JSON Stringify for JSONB Columns

**Scenario:** Store complex objects in Postgres JSONB

```json
{
  "input_data": "={{ JSON.stringify($node[\"Fetch Project\"].json) }}"
}
```

**Alternative with specific fields:**
```json
{
  "input_data": "={{ JSON.stringify({ 
    project: $node[\"Fetch Project\"].json.project_name,
    timestamp: $now
  }) }}"
}
```

---

## 🚨 COMMON MISTAKES & FIXES

### Mistake 1: Using $json Too Far from Source

**Problem:**
```javascript
Node A (fetches project) → Node B → Node C → Node D
// In Node D:
"project_id": "={{ $json.id }}" // ❌ Wrong! $json is from Node C, not A
```

**Fix:**
```javascript
"project_id": "={{ $node[\"Node A\"].json.id }}" // ✅ Correct
```

---

### Mistake 2: Incorrect Node Name

**Problem:**
```javascript
// Node is named "Fetch Next Project" (with capital letters)
"value": "={{ $node[\"fetch next project\"].json.id }}" // ❌ Case mismatch
```

**Fix:**
```javascript
"value": "={{ $node[\"Fetch Next Project\"].json.id }}" // ✅ Exact match
```

**Tip:** Copy-paste node names from n8n UI to avoid typos

---

### Mistake 3: Missing Quotes in Node Names

**Problem:**
```javascript
"value": "={{ $node[Fetch Next Project].json.id }}" // ❌ Missing quotes
```

**Fix:**
```javascript
"value": "={{ $node[\"Fetch Next Project\"].json.id }}" // ✅ With quotes
```

---

### Mistake 4: Accessing Non-Existent Fields

**Problem:**
```javascript
"value": "={{ $json.non_existent_field }}" // Returns undefined
```

**Fix:**
```javascript
// Use optional chaining (if supported)
"value": "={{ $json.non_existent_field || 'default_value' }}"

// Or check in Code node
if ($json.non_existent_field) {
  // Use it
} else {
  // Handle missing data
}
```

---

### Mistake 5: Wrong Syntax in SQL Queries

**Problem:**
```sql
-- ❌ Using ={{ }} in SQL (not needed)
WHERE id = ={{ $json.project_id }};
```

**Fix:**
```sql
-- ✅ Just use {{ }} in SQL
WHERE id = {{ $json.project_id }};
```

---

## 🔧 DEBUGGING EXPRESSIONS

### Method 1: Use Code Node to Log

**Insert temporary Code node:**
```javascript
console.log('Current data:', $json);
console.log('Available nodes:', Object.keys($node));
console.log('Specific node:', $node["Fetch Next Project"].json);

return { json: $input.item.json }; // Pass through
```

**Check logs:** n8n UI → Execution → Console Output

---

### Method 2: Test with Execute Node

**Steps:**
1. Click the node with expression
2. Click "Execute Node" (play button)
3. Check output in right panel
4. If error, hover over expression to see details

---

### Method 3: Use Set Node for Validation

**Create temporary Set node:**
```json
{
  "assignments": [
    {
      "name": "test_value",
      "value": "={{ $node[\"Some Node\"].json.field }}",
      "type": "string"
    }
  ]
}
```

Execute and verify output appears correctly.

---

## 📖 SPECIAL VARIABLES

### `$now`
**Current timestamp (ISO 8601)**
```javascript
"timestamp": "={{ $now }}"
// Output: "2026-01-28T14:30:00.000Z"
```

### `$today`
**Current date (no time)**
```javascript
"date": "={{ $today }}"
// Output: "2026-01-28"
```

### `$workflow`
**Workflow metadata**
```javascript
"workflow_name": "={{ $workflow.name }}"
"workflow_id": "={{ $workflow.id }}"
```

### `$execution`
**Execution metadata**
```javascript
"execution_id": "={{ $execution.id }}"
"execution_mode": "={{ $execution.mode }}" // "manual" or "webhook" or "trigger"
```

### `$input`
**All input data (for Code nodes)**
```javascript
const allItems = $input.all(); // Array of all items
const firstItem = $input.first(); // First item only
```

---

## 🎓 ADVANCED PATTERNS

### Pattern 1: Conditional String

```javascript
"status": "={{ $json.success ? 'completed' : 'failed' }}"
```

### Pattern 2: Math Operations

```javascript
"total": "={{ $json.price * $json.quantity }}"
"percentage": "={{ ($json.value / $json.total) * 100 }}"
```

### Pattern 3: String Manipulation

```javascript
"uppercase": "={{ $json.name.toUpperCase() }}"
"concat": "={{ $json.first_name + ' ' + $json.last_name }}"
"substring": "={{ $json.description.substring(0, 100) }}"
```

### Pattern 4: Array Operations

```javascript
// In Code node
const items = $json.items;
const filtered = items.filter(item => item.active);
const mapped = items.map(item => item.name);
const total = items.reduce((sum, item) => sum + item.price, 0);
```

### Pattern 5: Date Formatting

```javascript
// Using moment.js (if available in n8n)
"formatted_date": "={{ $now.format('YYYY-MM-DD HH:mm:ss') }}"

// Pure JavaScript
"date": "={{ new Date().toISOString().split('T')[0] }}"
```

---

## 📊 DATA STRUCTURES

### Accessing Nested Objects

```javascript
// JSON: { "user": { "profile": { "name": "John" } } }
"name": "={{ $json.user.profile.name }}"
```

### Accessing Arrays

```javascript
// JSON: { "items": [{"id": 1}, {"id": 2}] }
"first_id": "={{ $json.items[0].id }}"
"all_ids": "={{ $json.items.map(i => i.id) }}"
```

### Checking if Field Exists

```javascript
// Use optional chaining or conditional
"value": "={{ $json.field?.subfield || 'default' }}"
```

---

## ✅ BEST PRACTICES

1. **Name nodes descriptively**
   - ✅ "Fetch Next Project" (clear purpose)
   - ❌ "HTTP Request 1" (vague)

2. **Use $node[] for data that persists**
   - If data is used >1 node away, use `$node["Name"]`

3. **Add notes to nodes**
   - Explain what data the node provides
   - Example: "Outputs: project_id, project_name, mrs_data"

4. **Test expressions before saving**
   - Use Execute Node to verify output
   - Check for undefined/null values

5. **Use Code nodes for complex logic**
   - Don't try to fit complex operations in expression fields
   - Code nodes are more readable and debuggable

6. **Log liberally during development**
   - Add console.log in Code nodes
   - Remove once workflow is stable

---

## 🔗 QUICK REFERENCE TABLE

| Syntax | Use Case | Example |
|--------|----------|---------|
| `$json` | Previous node's output | `{{ $json.id }}` |
| `$node["Name"]` | Specific node output | `{{ $node["Fetch Project"].json.id }}` |
| `$("Name")` | Alternative node syntax | `{{ $("Fetch Project").item.json.id }}` |
| `$now` | Current timestamp | `{{ $now }}` |
| `$workflow.name` | Workflow metadata | `{{ $workflow.name }}` |
| `JSON.stringify()` | Object to string | `{{ JSON.stringify($json) }}` |
| `{{ ... }}` in SQL | Dynamic SQL values | `WHERE id = {{ $json.id }}` |

---

## 📞 TROUBLESHOOTING

**Error: "Cannot read property 'X' of undefined"**
→ The node you're referencing doesn't have that field
→ Check: Execute the source node and inspect its output

**Error: "Node not found"**
→ Node name is misspelled or renamed
→ Check: Verify exact node name in workflow

**Expression returns `[Object object]`**
→ Trying to display object as string
→ Fix: Use `JSON.stringify()` or access specific field

---

**Version:** 1.0  
**For:** Foundry v2.1  
**Reference:** n8n Documentation (docs.n8n.io)  

🏭 **"MASTER THE SYNTAX, MASTER THE WORKFLOW"**
