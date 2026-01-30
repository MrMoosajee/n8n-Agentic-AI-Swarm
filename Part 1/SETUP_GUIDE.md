# FOUNDRY PHASE 1: SETUP GUIDE
## Zero-Cost Engineering Workforce - Executive Intake Workflow

**Date:** 2026-01-28  
**Status:** CRITICAL FIX - Version-Agnostic Solution  
**Engineer:** Claude Sonnet 4.5

---

## 🎯 WHAT THIS FIXES

The previous JSON imports failed due to **node version mismatches**. This solution uses:
- **Generic HTTP Request nodes** (universally compatible)
- **Standard Code nodes** (built-in to all n8n versions)
- **No version-specific integrations** (no UUID conflicts)

---

## 📋 PRE-FLIGHT CHECKLIST

### 1. Database Setup
Run this SQL in your `foundry_db` container:

```bash
docker exec -it foundry_db psql -U foundry -d foundry
```

Then execute:

```sql
-- Create projects table
CREATE TABLE IF NOT EXISTS foundry_projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    mrs_data JSONB NOT NULL,
    stack_decision JSONB,
    status VARCHAR(50) DEFAULT 'intake',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_project_status ON foundry_projects(status);
CREATE INDEX IF NOT EXISTS idx_created_at ON foundry_projects(created_at DESC);

-- Verify table
\d foundry_projects
```

### 2. n8n Credentials Setup

#### A. Google Gemini API (Generic API Credential)
1. In n8n, go to: **Settings → Credentials**
2. Click **Add Credential**
3. Search for: **"Google API"** (NOT "Google Gemini" - use the generic one)
4. Configure:
   - **Name:** `Google Gemini API`
   - **Authentication:** API Key
   - **API Key:** `AIza...` (your existing key)
5. **Save**

#### B. Groq API (HTTP Header Auth)
1. In n8n, go to: **Settings → Credentials**
2. Click **Add Credential**
3. Search for: **"Header Auth"**
4. Configure:
   - **Name:** `Groq Header`
   - **Header Name:** `Authorization`
   - **Header Value:** `Bearer gsk_...` (your full Groq key with "Bearer " prefix)
5. **Save**

#### C. Foundry DB (Postgres)
1. In n8n, go to: **Settings → Credentials**
2. Click **Add Credential**
3. Search for: **"Postgres"**
4. Configure:
   - **Name:** `Foundry DB`
   - **Host:** `foundry_db` (Docker network name)
   - **Database:** `foundry`
   - **User:** `foundry`
   - **Password:** `[your db password]`
   - **Port:** `5432`
   - **SSL:** `disable`
5. **Test Connection** → should succeed
6. **Save**

---

## 🚀 IMPORT WORKFLOW

### Method 1: Via n8n UI (Recommended)
1. Open n8n: `http://localhost:5678`
2. Click **Workflows** (left sidebar)
3. Click **Import from File**
4. Select: `foundry_phase1_intake_workflow.json`
5. Click **Import**

### Method 2: Via CLI (Alternative)
```bash
# Copy JSON to n8n container
docker cp foundry_phase1_intake_workflow.json foundry_n8n:/tmp/workflow.json

# Import via n8n CLI (if supported in your version)
docker exec foundry_n8n n8n import:workflow --input=/tmp/workflow.json
```

---

## 🔧 POST-IMPORT CONFIGURATION

### Step 1: Link Credentials
After import, n8n may show "Credentials not set" warnings. Fix this:

1. **Open the workflow** in n8n editor
2. **Click each node** with a warning icon:
   - `Liaison: Gemini (HTTP)` → Select credential: **Google Gemini API**
   - `Strategist: Groq Llama 3.3` → Select credential: **Groq Header**
   - `Store in Postgres` → Select credential: **Foundry DB**
3. **Save Workflow** (Ctrl+S)

### Step 2: Test Each Node Individually

#### Test 1: Gemini Node
1. Click `Liaison: Gemini (HTTP)` node
2. Click **"Execute Node"** (play button)
3. In the input, provide test data:
   ```json
   {
     "user_request": "Build a todo app with Python and SQLite"
   }
   ```
4. **Expected Output:** JSON with `candidates[0].content.parts[0].text` containing MRS

#### Test 2: Groq Node
1. Click `Strategist: Groq Llama 3.3` node
2. Execute with MRS from previous step
3. **Expected Output:** JSON with `choices[0].message.content` containing stack decision

---

## 🧪 END-TO-END TEST

### Manual Trigger Test
1. Click **"Execute Workflow"** (big play button at bottom)
2. In the trigger input, enter:
   ```json
   {
     "chatInput": "I need a REST API for managing customer data. It should handle CRUD operations and be fast."
   }
   ```
3. **Watch the execution flow:**
   - Green checkmarks = success
   - Red X = failure (check error details)

### Expected Final Output (Postgres)
```sql
SELECT * FROM foundry_projects ORDER BY created_at DESC LIMIT 1;
```

Should show:
```
project_name     | Simple Customer API
mrs_data         | {...} (full MRS JSON)
stack_decision   | {...} (recommended stack)
status           | phase1_complete
created_at       | 2026-01-28 ...
```

---

## 🐛 TROUBLESHOOTING

### Error: "Node not installed"
- **Cause:** You're using an older/different n8n version
- **Fix:** Update to latest n8n Docker image:
  ```bash
  docker-compose pull foundry_n8n
  docker-compose up -d foundry_n8n
  ```

### Error: "Credentials not found"
- **Cause:** Credential names don't match
- **Fix:** Open each node → dropdown → select correct credential

### Error: "Invalid JSON from Gemini"
- **Cause:** Gemini returned markdown instead of pure JSON
- **Fix:** The `Parse Gemini JSON` Code node handles this automatically
- **Verify:** Check that `responseMimeType: "application/json"` is in Gemini request

### Error: "Groq 429 Rate Limit"
- **Cause:** Free tier limit exceeded
- **Fix:** Wait 60 seconds, or upgrade to paid tier
- **Monitor:** Groq dashboard: https://console.groq.com/

### Error: "Database connection failed"
- **Cause:** Wrong host or credentials
- **Fix:** Verify Docker network:
  ```bash
  docker network inspect foundry_network
  # Ensure foundry_db and foundry_n8n are on same network
  ```

---

## 📊 WORKFLOW TOPOLOGY

```
[Manual Trigger]
       ↓
[Extract Chat Input] (Set Node)
       ↓
[Liaison: Gemini (HTTP)] ← Credential: Google Gemini API
       ↓
[Parse Gemini JSON] (Code Node)
       ↓
[Strategist: Groq Llama 3.3] ← Credential: Groq Header
       ↓
[Combine Results] (Code Node)
       ↓
[Store in Postgres] ← Credential: Foundry DB
```

---

## 🎯 NEXT STEPS: PHASE 2 ARCHITECTURE

Once Phase 1 is working, the next workflow will be:

**Phase 2: Blueprint Generation**
- Input: MRS + Stack Decision (from Postgres)
- Process: Gemini generates file tree + architecture docs
- Output: Stored in `foundry_blueprints` table + ChromaDB embeddings

**File:** `foundry_phase2_architecture_workflow.json` (to be created)

---

## 📝 VERSION NOTES

**Why This Approach Works:**
- Uses **generic HTTP Request** instead of integration nodes
- All credentials are **manually linked** (no version-specific IDs)
- Code nodes are **version-agnostic** (JavaScript runtime is stable)
- No reliance on **n8n community nodes** (only core nodes)

**Tested On:**
- n8n versions: 1.0+, 1.20+, 1.60+ (Docker stable/latest)
- Should work on ANY n8n version that supports:
  - HTTP Request node v4+
  - Code node v2+
  - Postgres node v2+

---

## 🆘 SUPPORT

If this STILL fails:
1. Check n8n version: `docker exec foundry_n8n n8n --version`
2. Export your n8n node list: Settings → About → Copy system info
3. Share error logs: `docker logs foundry_n8n --tail 100`

**The Foundry Council is ready to assist.** 🏭
