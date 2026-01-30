#!/bin/bash

# ================================================================
# FOUNDRY PHASE 2 - DATABASE ISSUE DIAGNOSTIC & FIX
# ================================================================
# Purpose: Diagnose and fix database errors in Phase 2 workflow
# Usage: ./fix_phase2_db.sh
# ================================================================

set -e

echo "🔧 FOUNDRY PHASE 2 - DATABASE DIAGNOSTIC"
echo "========================================"
echo ""

# ----------------------------------------------------------------
# Step 1: Verify Database Connection
# ----------------------------------------------------------------
echo "📡 Step 1: Testing Database Connection..."

if docker exec foundry_db pg_isready -U foundry > /dev/null 2>&1; then
    echo "✅ Database is reachable"
else
    echo "❌ Database connection failed"
    echo "   Fix: docker-compose restart foundry_db"
    exit 1
fi

echo ""

# ----------------------------------------------------------------
# Step 2: Check Table Structure
# ----------------------------------------------------------------
echo "🗄️  Step 2: Verifying Table Structures..."

# Check foundry_blueprints
echo ""
echo "Checking foundry_blueprints table..."
docker exec foundry_db psql -U foundry -d foundry -c "\d foundry_blueprints" > /tmp/blueprints_schema.txt 2>&1

if grep -q "Table \"public.foundry_blueprints\"" /tmp/blueprints_schema.txt; then
    echo "✅ foundry_blueprints exists"
    
    # Show schema
    echo ""
    echo "Current schema:"
    docker exec foundry_db psql -U foundry -d foundry -c "\d foundry_blueprints"
else
    echo "❌ foundry_blueprints table missing!"
    echo "   Creating table..."
    
    docker exec -i foundry_db psql -U foundry -d foundry <<'EOF'
CREATE TABLE IF NOT EXISTS foundry_blueprints (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    blueprint_type VARCHAR(50) NOT NULL,
    content JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blueprint_project ON foundry_blueprints(project_id);
EOF
    
    echo "✅ Table created"
fi

echo ""

# Check foundry_agent_log
echo "Checking foundry_agent_log table..."
docker exec foundry_db psql -U foundry -d foundry -c "\d foundry_agent_log" > /tmp/agent_log_schema.txt 2>&1

if grep -q "Table \"public.foundry_agent_log\"" /tmp/agent_log_schema.txt; then
    echo "✅ foundry_agent_log exists"
else
    echo "❌ foundry_agent_log table missing!"
    echo "   Creating table..."
    
    docker exec -i foundry_db psql -U foundry -d foundry <<'EOF'
CREATE TABLE IF NOT EXISTS foundry_agent_log (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    agent_role VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    input_data JSONB,
    output_data JSONB,
    model_used VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_log_project ON foundry_agent_log(project_id);
CREATE INDEX IF NOT EXISTS idx_log_agent ON foundry_agent_log(agent_role);
CREATE INDEX IF NOT EXISTS idx_log_created ON foundry_agent_log(created_at DESC);
EOF
    
    echo "✅ Table created"
fi

echo ""

# ----------------------------------------------------------------
# Step 3: Check for Data Type Mismatches
# ----------------------------------------------------------------
echo "🔍 Step 3: Checking for Common Issues..."

# Check if content column is JSONB (not JSON or TEXT)
CONTENT_TYPE=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT data_type FROM information_schema.columns WHERE table_name = 'foundry_blueprints' AND column_name = 'content';" | tr -d ' ')

echo "   content column type: $CONTENT_TYPE"

if [ "$CONTENT_TYPE" != "jsonb" ]; then
    echo "⚠️  WARNING: content column is not JSONB (it's $CONTENT_TYPE)"
    echo "   This may cause issues. Recreating column..."
    
    docker exec -i foundry_db psql -U foundry -d foundry <<'EOF'
-- Backup existing data
CREATE TEMP TABLE blueprints_backup AS SELECT * FROM foundry_blueprints;

-- Drop and recreate table with correct types
DROP TABLE foundry_blueprints CASCADE;

CREATE TABLE foundry_blueprints (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    blueprint_type VARCHAR(50) NOT NULL,
    content JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Restore data (if any existed)
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version, created_at)
SELECT project_id, blueprint_type, content::jsonb, version, created_at 
FROM blueprints_backup;

-- Recreate indexes
CREATE INDEX idx_blueprint_project ON foundry_blueprints(project_id);
EOF
    
    echo "✅ Column fixed"
fi

echo ""

# ----------------------------------------------------------------
# Step 4: Test Insert Operations
# ----------------------------------------------------------------
echo "🧪 Step 4: Testing Insert Operations..."

# Test project exists
PROJECT_COUNT=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_projects WHERE status = 'phase1_complete';" | tr -d ' ')

if [ "$PROJECT_COUNT" -eq 0 ]; then
    echo "⚠️  No projects ready for Phase 2"
    echo "   Creating test project..."
    
    docker exec -i foundry_db psql -U foundry -d foundry <<'EOF'
INSERT INTO foundry_projects (
    project_name,
    mrs_data,
    stack_decision,
    status
) VALUES (
    'Test Blueprint Storage',
    '{"project_name": "Test Blueprint Storage", "description": "Test", "requirements": ["test"], "constraints": {"budget": "R0"}, "success_criteria": ["test"]}'::jsonb,
    '{"recommended_stack": {"primary_language": "Python", "framework": "FastAPI", "database": "SQLite", "reasoning": "Test"}}'::jsonb,
    'phase1_complete'
) ON CONFLICT DO NOTHING;
EOF
    
    echo "✅ Test project created"
else
    echo "✅ Found $PROJECT_COUNT project(s) ready for Phase 2"
fi

# Test blueprint insert
echo ""
echo "Testing blueprint insert..."

TEST_PROJECT_ID=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT id FROM foundry_projects WHERE status = 'phase1_complete' LIMIT 1;" | tr -d ' ')

if [ -n "$TEST_PROJECT_ID" ]; then
    echo "   Using project ID: $TEST_PROJECT_ID"
    
    # Try inserting a test blueprint
    docker exec -i foundry_db psql -U foundry -d foundry <<EOF
INSERT INTO foundry_blueprints (
    project_id,
    blueprint_type,
    content,
    version
) VALUES (
    $TEST_PROJECT_ID,
    'test_blueprint',
    '{"test": "data", "structure": [{"path": "test.py", "type": "file"}]}'::jsonb,
    1
);
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Test insert succeeded"
        
        # Clean up test data
        docker exec foundry_db psql -U foundry -d foundry -c "DELETE FROM foundry_blueprints WHERE blueprint_type = 'test_blueprint';" > /dev/null 2>&1
    else
        echo "❌ Test insert failed"
        echo "   Check error above for details"
    fi
else
    echo "⚠️  No project ID available for testing"
fi

echo ""

# ----------------------------------------------------------------
# Step 5: Check Permissions
# ----------------------------------------------------------------
echo "🔐 Step 5: Verifying Permissions..."

docker exec -i foundry_db psql -U foundry -d foundry <<'EOF'
-- Grant all permissions to foundry user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO foundry;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO foundry;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO foundry;
EOF

echo "✅ Permissions granted"

echo ""

# ----------------------------------------------------------------
# Step 6: Check for Constraint Violations
# ----------------------------------------------------------------
echo "🔗 Step 6: Checking Foreign Key Constraints..."

# Check if there are any orphaned references
ORPHANED=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_blueprints WHERE project_id NOT IN (SELECT id FROM foundry_projects);" | tr -d ' ')

if [ "$ORPHANED" -gt 0 ]; then
    echo "⚠️  Found $ORPHANED orphaned blueprint(s)"
    echo "   Cleaning up..."
    docker exec foundry_db psql -U foundry -d foundry -c "DELETE FROM foundry_blueprints WHERE project_id NOT IN (SELECT id FROM foundry_projects);"
    echo "✅ Cleaned"
else
    echo "✅ No orphaned records"
fi

echo ""

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
echo "========================================"
echo "📊 DIAGNOSTIC SUMMARY"
echo "========================================"
echo ""

# Count current data
PROJECTS=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_projects;" | tr -d ' ')
BLUEPRINTS=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_blueprints;" | tr -d ' ')
LOGS=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_agent_log;" | tr -d ' ')

echo "Current Database State:"
echo "  • Projects: $PROJECTS"
echo "  • Blueprints: $BLUEPRINTS"
echo "  • Agent Logs: $LOGS"
echo ""

echo "✅ DATABASE DIAGNOSTIC COMPLETE"
echo ""
echo "Next Steps:"
echo "1. Try executing Phase 2 workflow again in n8n"
echo "2. If errors persist, check specific node errors below"
echo "3. Run: docker logs foundry_db --tail 50"
echo ""

# ----------------------------------------------------------------
# Generate SQL for Manual Testing
# ----------------------------------------------------------------
echo "📝 Manual Test SQL (copy-paste into postgres):"
echo ""
cat <<'EOF'
-- Test blueprint insert manually:
INSERT INTO foundry_blueprints (
    project_id,
    blueprint_type,
    content,
    version
) VALUES (
    (SELECT id FROM foundry_projects WHERE status = 'phase1_complete' LIMIT 1),
    'manual_test',
    '{"test": "data"}'::jsonb,
    1
) RETURNING id, project_id, blueprint_type;

-- Check result:
SELECT * FROM foundry_blueprints WHERE blueprint_type = 'manual_test';

-- Clean up:
DELETE FROM foundry_blueprints WHERE blueprint_type = 'manual_test';
EOF

echo ""
echo "========================================"
