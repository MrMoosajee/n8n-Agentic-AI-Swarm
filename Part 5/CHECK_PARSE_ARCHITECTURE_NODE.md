# CHECKING AND FIXING "PARSE ARCHITECTURE" NODE
## Step-by-Step Verification

---

## 🔍 STEP 1: CHECK WHAT'S CURRENTLY IN THE NODE

### How to View Current Code

1. **Open Phase 2 workflow** in n8n
2. **Click on "Parse Architecture"** node (the Code node after Gemini)
3. **Look in the right panel** under "JavaScript Code"
4. **Copy the code** you see there

### What You Might See

You might have one of these versions:

**❌ Version A - Too Simple (WRONG):**
```javascript
return { json: $input.item.json };
```

**❌ Version B - Missing Architecture Parsing (WRONG):**
```javascript
const geminiResponse = $input.item.json;
const text = geminiResponse.candidates[0].content.parts[0].text;
return { json: { text: text } };
```

**✅ Version C - Complete (CORRECT):**
```javascript
// Extract and parse Gemini architecture response
const geminiResponse = $input.item.json;
const previousData = $('Build Architect Prompt').item.json;

if (!geminiResponse.candidates || !geminiResponse.candidates[0]) {
  throw new Error('Invalid Gemini response: ' + JSON.stringify(geminiResponse));
}

const generatedText = geminiResponse.candidates[0].content.parts[0].text;

// Parse the architecture JSON
let architecture;
try {
  architecture = JSON.parse(generatedText);
} catch (e) {
  // Try extracting from markdown
  const jsonMatch = generatedText.match(/```json\n([\s\S]*?)\n```/) || generatedText.match(/```\n([\s\S]*?)\n```/);
  if (jsonMatch) {
    architecture = JSON.parse(jsonMatch[1]);
  } else {
    // Try extracting from first { to last }
    const start = generatedText.indexOf('{');
    const end = generatedText.lastIndexOf('}') + 1;
    if (start !== -1 && end > start) {
      architecture = JSON.parse(generatedText.substring(start, end));
    } else {
      throw new Error('Failed to extract JSON from Gemini response: ' + e.message);
    }
  }
}

// Validate architecture structure
if (!architecture.file_tree || !architecture.architecture || !architecture.dependencies) {
  throw new Error('Architecture missing required fields: file_tree, architecture, or dependencies');
}

// Combine with project data
return {
  json: {
    project_id: previousData.project_id,
    project_name: previousData.project_name,
    architecture: architecture,
    timestamp: new Date().toISOString()
  }
};
```

---

## 🔧 STEP 2: FIX THE NODE

### If You Have Version A or B (Incomplete Code)

**Replace ALL the code in "Parse Architecture" node with this:**

```javascript
// Extract and parse Gemini architecture response
const geminiResponse = $input.item.json;
const previousData = $('Build Architect Prompt').item.json;

if (!geminiResponse.candidates || !geminiResponse.candidates[0]) {
  throw new Error('Invalid Gemini response: ' + JSON.stringify(geminiResponse));
}

const generatedText = geminiResponse.candidates[0].content.parts[0].text;

// Parse the architecture JSON
let architecture;
try {
  architecture = JSON.parse(generatedText);
} catch (e) {
  // Try extracting from markdown
  const jsonMatch = generatedText.match(/```json\n([\s\S]*?)\n```/) || generatedText.match(/```\n([\s\S]*?)\n```/);
  if (jsonMatch) {
    architecture = JSON.parse(jsonMatch[1]);
  } else {
    // Try extracting from first { to last }
    const start = generatedText.indexOf('{');
    const end = generatedText.lastIndexOf('}') + 1;
    if (start !== -1 && end > start) {
      architecture = JSON.parse(generatedText.substring(start, end));
    } else {
      throw new Error('Failed to extract JSON from Gemini response: ' + e.message);
    }
  }
}

// Validate architecture structure
if (!architecture.file_tree || !architecture.architecture || !architecture.dependencies) {
  throw new Error('Architecture missing required fields: file_tree, architecture, or dependencies');
}

// Combine with project data
return {
  json: {
    project_id: previousData.project_id,
    project_name: previousData.project_name,
    architecture: architecture,
    timestamp: new Date().toISOString()
  }
};
```

**Then:**
1. Click **"Save"** (Ctrl+S or Cmd+S)
2. Test by clicking **"Execute Node"** on "Parse Architecture"

---

## 🧪 STEP 3: TEST THE NODE

### Test Without Full Workflow

1. Click **"Architect: Gemini Pro"** node
2. Click **"Execute Node"**
3. Wait for it to complete (green checkmark)
4. Now click **"Parse Architecture"** node
5. Click **"Execute Node"**

### What You Should See in Output Panel

**✅ CORRECT OUTPUT:**
```json
{
  "project_id": 1,
  "project_name": "Some Project Name",
  "architecture": {
    "file_tree": {
      "root": "project_name",
      "structure": [
        {
          "path": "src/",
          "type": "directory",
          "purpose": "Main source code"
        }
      ]
    },
    "architecture": {
      "layers": [...]
    },
    "dependencies": [
      {
        "name": "fastapi",
        "version": "0.104.1",
        "purpose": "..."
      }
    ],
    "implementation_order": [...]
  },
  "timestamp": "2026-01-29T..."
}
```

**Key things to verify:**
- ✅ `project_id` is a number
- ✅ `project_name` is a string
- ✅ `architecture` is an object with 4 sub-objects:
  - `file_tree`
  - `architecture`
  - `dependencies`
  - `implementation_order`

**❌ WRONG OUTPUT (if code is incorrect):**
```json
{
  "text": "{\"file_tree\": ...}"  // ← String instead of parsed object
}
```

Or:
```json
{
  "candidates": [...]  // ← Raw Gemini response, not parsed
}
```

---

## 🚨 COMMON ISSUES

### Issue 1: "Cannot read property 'item' of undefined"

**Error Message:**
```
Cannot read property 'item' of undefined at $('Build Architect Prompt')
```

**Fix:** Change this line:
```javascript
const previousData = $('Build Architect Prompt').item.json;
```

To this (using $node syntax):
```javascript
const previousData = $node["Build Architect Prompt"].json;
```

**Full corrected version:**
```javascript
// Extract and parse Gemini architecture response
const geminiResponse = $input.item.json;
const previousData = $node["Build Architect Prompt"].json;  // ← FIXED

if (!geminiResponse.candidates || !geminiResponse.candidates[0]) {
  throw new Error('Invalid Gemini response: ' + JSON.stringify(geminiResponse));
}

const generatedText = geminiResponse.candidates[0].content.parts[0].text;

// Parse the architecture JSON
let architecture;
try {
  architecture = JSON.parse(generatedText);
} catch (e) {
  // Try extracting from markdown
  const jsonMatch = generatedText.match(/```json\n([\s\S]*?)\n```/) || generatedText.match(/```\n([\s\S]*?)\n```/);
  if (jsonMatch) {
    architecture = JSON.parse(jsonMatch[1]);
  } else {
    // Try extracting from first { to last }
    const start = generatedText.indexOf('{');
    const end = generatedText.lastIndexOf('}') + 1;
    if (start !== -1 && end > start) {
      architecture = JSON.parse(generatedText.substring(start, end));
    } else {
      throw new Error('Failed to extract JSON from Gemini response: ' + e.message);
    }
  }
}

// Validate architecture structure
if (!architecture.file_tree || !architecture.architecture || !architecture.dependencies) {
  throw new Error('Architecture missing required fields: file_tree, architecture, or dependencies');
}

// Combine with project data
return {
  json: {
    project_id: previousData.project_id,
    project_name: previousData.project_name,
    architecture: architecture,
    timestamp: new Date().toISOString()
  }
};
```

---

### Issue 2: "Architecture missing required fields"

**This means Gemini didn't return the expected structure.**

**Quick Debug:** Add logging before the validation:
```javascript
// ... (all the code above)

// Add this line for debugging:
console.log('Parsed architecture:', JSON.stringify(architecture, null, 2));

// Validate architecture structure
if (!architecture.file_tree || !architecture.architecture || !architecture.dependencies) {
  throw new Error('Architecture missing required fields: file_tree, architecture, or dependencies');
}

// ... (rest of code)
```

Then execute the node and check the console output to see what Gemini actually returned.

---

### Issue 3: "Failed to extract JSON from Gemini response"

**This means Gemini returned text instead of JSON.**

**Fix:** Check the "Architect: Gemini Pro" node's request includes:
```json
{
  "generationConfig": {
    "temperature": 0.4,
    "maxOutputTokens": 8192,
    "responseMimeType": "application/json"  // ← Very important!
  }
}
```

---

## 📋 COMPLETE CHECKLIST

After fixing "Parse Architecture" node:

- [ ] Code includes Gemini response extraction
- [ ] Code includes JSON parsing with fallbacks
- [ ] Code validates required fields (file_tree, architecture, dependencies, implementation_order)
- [ ] Code combines with previous data (project_id, project_name)
- [ ] Test execution shows correct output structure
- [ ] Output has `architecture` object with 4 sub-objects
- [ ] Save workflow (Ctrl+S)

---

## ✅ NEXT STEPS

Once "Parse Architecture" is working correctly:

1. **Fix the Store nodes** (remove JSON.stringify, change type to JSON)
2. **Execute full workflow**
3. **Verify in database:**
   ```sql
   SELECT blueprint_type, jsonb_typeof(content) 
   FROM foundry_blueprints 
   ORDER BY blueprint_type;
   ```
   Should show:
   ```
   architecture        | object
   dependencies        | array
   file_tree           | object
   implementation_plan | array
   ```

---

## 🆘 IF STILL STUCK

Share the following info:

1. **Current code in "Parse Architecture" node** (copy-paste)
2. **Error message** (exact text)
3. **Output from "Architect: Gemini Pro" node** (first 100 lines)

Then I can provide a custom fix for your specific situation.

---

🏭 **"PARSE WITH PRECISION, STORE WITH CONFIDENCE"**
