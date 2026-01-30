#!/bin/bash

# ================================================================
# FOUNDRY PHASE 1 - AUTOMATED SETUP SCRIPT
# ================================================================
# Purpose: Initialize database and prepare workflow for import
# Usage: ./setup_foundry.sh
# ================================================================

set -e  # Exit on error

echo "🏭 FOUNDRY PHASE 1 SETUP"
echo "================================"
echo ""

# ----------------------------------------------------------------
# Step 1: Verify Docker Containers
# ----------------------------------------------------------------
echo "📦 Step 1: Checking Docker containers..."

if ! docker ps | grep -q "foundry_n8n"; then
    echo "❌ ERROR: foundry_n8n container not running"
    echo "   Start it with: docker-compose up -d foundry_n8n"
    exit 1
fi

if ! docker ps | grep -q "foundry_db"; then
    echo "❌ ERROR: foundry_db container not running"
    echo "   Start it with: docker-compose up -d foundry_db"
    exit 1
fi

echo "✅ Containers are running"
echo ""

# ----------------------------------------------------------------
# Step 2: Initialize Database
# ----------------------------------------------------------------
echo "🗄️  Step 2: Initializing database..."

# Copy SQL file to container
docker cp init_db.sql foundry_db:/tmp/init_db.sql

# Execute SQL
docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql > /tmp/db_init.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Database initialized successfully"
    
    # Verify tables
    TABLE_COUNT=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'foundry_%';")
    echo "   → Created $TABLE_COUNT tables"
else
    echo "❌ Database initialization failed. Check logs:"
    cat /tmp/db_init.log
    exit 1
fi

echo ""

# ----------------------------------------------------------------
# Step 3: Check n8n Version
# ----------------------------------------------------------------
echo "🔍 Step 3: Checking n8n version..."

N8N_VERSION=$(docker exec foundry_n8n n8n --version 2>/dev/null || echo "unknown")
echo "   → n8n version: $N8N_VERSION"
echo ""

# ----------------------------------------------------------------
# Step 4: Prepare Workflow for Import
# ----------------------------------------------------------------
echo "📋 Step 4: Preparing workflow..."

if [ -f "foundry_phase1_intake_workflow.json" ]; then
    echo "✅ Workflow JSON found"
    
    # Copy to a web-accessible location (if needed)
    mkdir -p /tmp/foundry_workflows
    cp foundry_phase1_intake_workflow.json /tmp/foundry_workflows/
    
    echo "   → Workflow ready for import"
    echo "   → Location: $(pwd)/foundry_phase1_intake_workflow.json"
else
    echo "❌ ERROR: foundry_phase1_intake_workflow.json not found"
    exit 1
fi

echo ""

# ----------------------------------------------------------------
# Step 5: Verify n8n Accessibility
# ----------------------------------------------------------------
echo "🌐 Step 5: Verifying n8n accessibility..."

N8N_PORT=$(docker port foundry_n8n 5678 2>/dev/null | cut -d: -f2)
if [ -z "$N8N_PORT" ]; then
    N8N_PORT=5678
fi

if curl -s "http://localhost:$N8N_PORT/healthz" > /dev/null 2>&1; then
    echo "✅ n8n is accessible at http://localhost:$N8N_PORT"
else
    echo "⚠️  WARNING: n8n health check failed"
    echo "   Try accessing: http://localhost:$N8N_PORT"
fi

echo ""

# ----------------------------------------------------------------
# Final Instructions
# ----------------------------------------------------------------
echo "================================"
echo "✅ SETUP COMPLETE"
echo "================================"
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "1. Open n8n:"
echo "   → http://localhost:$N8N_PORT"
echo ""
echo "2. Configure Credentials (if not done already):"
echo "   a. Google Gemini API:"
echo "      - Type: 'Google API'"
echo "      - Name: 'Google Gemini API'"
echo "      - API Key: AIza..."
echo ""
echo "   b. Groq Header Auth:"
echo "      - Type: 'Header Auth'"
echo "      - Name: 'Groq Header'"
echo "      - Header: 'Authorization'"
echo "      - Value: 'Bearer gsk_...'"
echo ""
echo "   c. Foundry DB:"
echo "      - Type: 'Postgres'"
echo "      - Name: 'Foundry DB'"
echo "      - Host: 'foundry_db'"
echo "      - Database: 'foundry'"
echo "      - User: 'foundry'"
echo "      - Password: [your password]"
echo ""
echo "3. Import Workflow:"
echo "   → Click 'Workflows' → 'Import from File'"
echo "   → Select: foundry_phase1_intake_workflow.json"
echo "   → Link credentials to each node"
echo "   → Save workflow"
echo ""
echo "4. Test Workflow:"
echo "   → Click 'Execute Workflow'"
echo "   → Input: {\"chatInput\": \"Build a todo app\"}"
echo "   → Verify green checkmarks on all nodes"
echo ""
echo "5. Verify Database:"
echo "   → docker exec -it foundry_db psql -U foundry -d foundry"
echo "   → SELECT * FROM foundry_projects;"
echo ""
echo "📖 For detailed instructions, see: SETUP_GUIDE.md"
echo ""
echo "🏭 THE FOUNDRY IS READY FOR PHASE 1 OPERATIONS"
echo "================================"
