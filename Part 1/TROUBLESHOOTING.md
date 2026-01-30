# FOUNDRY TROUBLESHOOTING GUIDE
## Common Issues & Solutions for Phase 1 Setup

---

## 🚨 IMPORT ERRORS

### Error: "Node not installed" or "Missing node types"

**Symptom:**
```
Error: Node type 'n8n-nodes-base.googleGemini' is not known
```

**Root Cause:** Version mismatch between JSON and your n8n installation

**Solution:**
1. **Do NOT use integration-specific nodes** (they change between versions)
2. Use the provided `foundry_phase1_intake_workflow.json` which uses generic HTTP nodes
3. If you modified the JSON, ensure you're using:
   - `n8n-nodes-base.httpRequest` (NOT `googleGemini` or `groqChat`)
   - `n8n-nodes-base.code` (NOT custom code nodes)
   - `n8n-nodes-base.postgres` (core node)

**Prevention:** Always use generic HTTP Request nodes for API calls instead of integration nodes

---

### Error: "Invalid workflow JSON"

**Symptom:**
```
Failed to parse workflow JSON: Unexpected token...
```

**Root Cause:** Corrupted JSON or encoding issue

**Solution:**
```bash
# Validate JSON syntax
cat foundry_phase1_intake_workflow.json | jq . > /dev/null

# If error, regenerate the file
# Request Claude to create a fresh workflow JSON
```

---

## 🔐 CREDENTIAL ERRORS

### Error: "No credentials found" after import

**Symptom:** Orange warning badges on nodes after importing workflow

**Root Cause:** Credential IDs in JSON don't match your n8n installation

**Solution:**
1. Click each node with warning
2. In the right panel, find "Credentials" section
3. Select credential from dropdown (e.g., "Google Gemini API")
4. Save workflow (Ctrl+S)

**Note:** This is EXPECTED behavior - credentials must be manually linked for security

---

### Error: "Authentication failed" on Gemini node

**Symptom:**
```
401 Unauthorized
API key not valid
```

**Possible Causes & Fixes:**

1. **Wrong API Key Format**
   ```
   ❌ Bad: credentials.apiKey = "AIza..."
   ✅ Good: URL parameter ?key=AIza...
   ```
   → Check that Gemini HTTP node uses `queryParameters` not `headers`

2. **API Key Disabled**
   → Verify at: https://aistudio.google.com/app/apikey
   → Ensure "Generative Language API" is enabled

3. **Quota Exceeded**
   → Check quota: https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas
   → Free tier: 15 requests/minute

**Test Credential Manually:**
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=YOUR_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"Say hello"}]}]}'
```

---

### Error: "Authentication failed" on Groq node

**Symptom:**
```
401 Unauthorized
Invalid authentication credentials
```

**Solution:**
1. Verify Groq credential in n8n:
   - Type: **Header Auth** (NOT Bearer Token)
   - Name: `Authorization`
   - Value: `Bearer gsk_...` (must include "Bearer " prefix)

2. Test API key directly:
```bash
curl -X POST https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer YOUR_GROQ_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"Hi"}]}'
```

3. Check Groq dashboard for:
   - Key status: https://console.groq.com/keys
   - Rate limits: Free tier = 30 requests/minute

---

## 🗄️ DATABASE ERRORS

### Error: "Connection refused" to Postgres

**Symptom:**
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Root Cause:** n8n trying to connect to localhost instead of Docker network

**Solution:**
1. In Postgres credential, use **Docker service name**:
   ```
   Host: foundry_db  ← NOT "localhost" or "127.0.0.1"
   ```

2. Verify containers are on same network:
```bash
docker network inspect foundry_network | grep -E "foundry_n8n|foundry_db"
```

3. If they're not connected:
```bash
docker network connect foundry_network foundry_n8n
docker network connect foundry_network foundry_db
```

---

### Error: "Table does not exist" 

**Symptom:**
```
relation "foundry_projects" does not exist
```

**Solution:**
```bash
# Run database initialization
docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql

# Verify tables exist
docker exec foundry_db psql -U foundry -d foundry -c "\dt"
```

---

### Error: "Permission denied for table"

**Symptom:**
```
ERROR: permission denied for table foundry_projects
```

**Solution:**
```sql
-- Grant permissions to foundry user
docker exec -it foundry_db psql -U postgres -d foundry

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO foundry;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO foundry;
```

---

## 🔄 EXECUTION ERRORS

### Error: "Cannot read property 'content' of undefined"

**Symptom:** Parse Gemini JSON node fails with undefined error

**Root Cause:** Gemini response structure changed or was empty

**Solution:**
1. Check Gemini node output:
   ```
   Expected: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
   ```

2. If structure is different, update Parse Gemini JSON code:
```javascript
// Add error handling
const geminiResponse = $input.item.json;

if (!geminiResponse.candidates || !geminiResponse.candidates[0]) {
  throw new Error('Invalid Gemini response: ' + JSON.stringify(geminiResponse));
}

const generatedText = geminiResponse.candidates[0].content.parts[0].text;
```

---

### Error: "Invalid JSON" from Gemini

**Symptom:** Parse Gemini JSON fails to extract valid JSON

**Root Cause:** Gemini returned markdown code blocks instead of raw JSON

**Current Fix:** The Parse Gemini JSON node already handles this:
```javascript
const jsonMatch = generatedText.match(/```json\n([\s\S]*?)\n```/)
```

**If still failing:**
1. Check Gemini request includes: `responseMimeType: "application/json"`
2. Add more robust parsing:
```javascript
// Try multiple extraction methods
let mrs;
try {
  mrs = JSON.parse(generatedText);
} catch {
  // Extract from markdown
  const match = generatedText.match(/```(?:json)?\n?([\s\S]*?)\n?```/);
  if (match) {
    mrs = JSON.parse(match[1]);
  } else {
    // Extract from first { to last }
    const start = generatedText.indexOf('{');
    const end = generatedText.lastIndexOf('}') + 1;
    mrs = JSON.parse(generatedText.substring(start, end));
  }
}
```

---

### Error: "Rate limit exceeded" on Groq

**Symptom:**
```
429 Too Many Requests
Rate limit reached for model
```

**Solutions:**
1. **Wait and retry** (free tier resets every minute)
2. **Reduce request frequency** (add delay between executions)
3. **Switch models temporarily:**
   ```
   llama-3.3-70b-versatile  → llama-3.1-70b-versatile
   ```
4. **Consider paid tier** if building at scale

---

## 🧩 WORKFLOW LOGIC ERRORS

### Error: "Cannot access property of previous node"

**Symptom:**
```
$('Parse Gemini JSON').item.json is undefined
```

**Root Cause:** Node reference syntax error or node name changed

**Solution:**
1. Verify node names exactly match:
   ```javascript
   $('Parse Gemini JSON')  ← Name must be exact, including spaces
   ```

2. Alternative: Use positional reference:
   ```javascript
   $input.item.json  ← References previous node output
   ```

3. Debug by logging:
```javascript
console.log('Available nodes:', Object.keys($input));
console.log('Current item:', $input.item.json);
```

---

### Error: Workflow executes but database is empty

**Symptom:** Execution shows green checkmarks, but no data in Postgres

**Solution:**
1. Check Postgres node executed:
   - Click on "Store in Postgres" node
   - Verify it has green checkmark
   - Check output panel for errors

2. Verify data manually:
```sql
docker exec -it foundry_db psql -U foundry -d foundry

SELECT COUNT(*) FROM foundry_projects;
SELECT * FROM foundry_projects ORDER BY created_at DESC LIMIT 1;
```

3. Check n8n logs:
```bash
docker logs foundry_n8n --tail 100 | grep -i error
```

---

## 🔧 PERFORMANCE ISSUES

### Issue: Workflow execution is very slow

**Possible Causes:**

1. **Large Gemini context**
   → Reduce prompt length in Liaison node
   → Use Gemini Flash instead of Pro for faster responses

2. **Database connection pooling**
   → Add to Postgres credential:
   ```
   Max Connections: 5
   Connection Timeout: 30000
   ```

3. **n8n memory limit**
   → Check container memory:
   ```bash
   docker stats foundry_n8n
   ```
   → If using >90% of 4GB, increase limit in docker-compose.yml

---

## 🏥 HEALTH CHECKS

### Quick Diagnostic Script

```bash
#!/bin/bash

echo "🏥 FOUNDRY HEALTH CHECK"
echo "======================="

# Container status
echo "📦 Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep foundry

# Database connectivity
echo ""
echo "🗄️  Database:"
docker exec foundry_db pg_isready -U foundry
docker exec foundry_db psql -U foundry -d foundry -c "SELECT COUNT(*) FROM foundry_projects;" -t

# n8n health
echo ""
echo "🌐 n8n:"
curl -s http://localhost:5678/healthz || echo "FAILED"

# Network
echo ""
echo "🌐 Network:"
docker network inspect foundry_network --format '{{range .Containers}}{{.Name}} {{end}}'

echo ""
echo "======================="
```

Save as `health_check.sh`, make executable, and run anytime

---

## 🆘 LAST RESORT: COMPLETE RESET

If nothing works, nuclear option:

```bash
# 1. Stop all containers
docker-compose down

# 2. Remove volumes (⚠️ DESTROYS ALL DATA)
docker volume rm foundry_db_data foundry_n8n_data

# 3. Rebuild from scratch
docker-compose up -d

# 4. Re-run setup
./setup_foundry.sh

# 5. Re-import workflow
# (Open n8n UI and import JSON manually)
```

---

## 📞 GETTING HELP

If you're still stuck:

1. **Gather diagnostics:**
   ```bash
   docker logs foundry_n8n > n8n.log
   docker logs foundry_db > db.log
   docker exec foundry_n8n n8n --version > version.txt
   ```

2. **Share:**
   - The specific error message
   - n8n version
   - Workflow JSON (if modified)
   - Logs (sanitize credentials first!)

3. **Community resources:**
   - n8n Forum: https://community.n8n.io
   - n8n Discord: https://discord.gg/n8n
   - Foundry GitHub Issues: [Your repo here]

---

**Remember:** The Foundry is a zero-cost system. Every error is a learning opportunity to build more resilient automation. 🏭
