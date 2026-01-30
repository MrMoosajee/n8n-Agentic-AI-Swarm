#!/bin/bash

# ================================================================
# FOUNDRY PHASE 2 - PRE-FLIGHT VALIDATION SCRIPT
# ================================================================
# Purpose: Verify all prerequisites before importing Phase 2
# Usage: ./validate_phase2.sh
# ================================================================

set -e

echo "🏭 FOUNDRY PHASE 2 - PRE-FLIGHT CHECK"
echo "====================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ----------------------------------------------------------------
# Check 1: Docker Containers Running
# ----------------------------------------------------------------
echo "📦 Check 1: Docker Containers"
echo "-------------------------------------"

if docker ps | grep -q "foundry_n8n"; then
    echo "✅ foundry_n8n is running"
    ((PASS_COUNT++))
else
    echo "❌ foundry_n8n is NOT running"
    ((FAIL_COUNT++))
fi

if docker ps | grep -q "foundry_db"; then
    echo "✅ foundry_db is running"
    ((PASS_COUNT++))
else
    echo "❌ foundry_db is NOT running"
    ((FAIL_COUNT++))
fi

echo ""

# ----------------------------------------------------------------
# Check 2: Database Schema
# ----------------------------------------------------------------
echo "🗄️  Check 2: Database Schema"
echo "-------------------------------------"

# Check foundry_projects table
if docker exec foundry_db psql -U foundry -d foundry -t -c "\d foundry_projects" > /dev/null 2>&1; then
    echo "✅ foundry_projects table exists"
    ((PASS_COUNT++))
else
    echo "❌ foundry_projects table missing"
    ((FAIL_COUNT++))
fi

# Check foundry_blueprints table
if docker exec foundry_db psql -U foundry -d foundry -t -c "\d foundry_blueprints" > /dev/null 2>&1; then
    echo "✅ foundry_blueprints table exists"
    ((PASS_COUNT++))
else
    echo "❌ foundry_blueprints table missing (run init_db.sql)"
    ((FAIL_COUNT++))
fi

# Check foundry_agent_log table
if docker exec foundry_db psql -U foundry -d foundry -t -c "\d foundry_agent_log" > /dev/null 2>&1; then
    echo "✅ foundry_agent_log table exists"
    ((PASS_COUNT++))
else
    echo "⚠️  foundry_agent_log table missing (optional, but recommended)"
    ((WARN_COUNT++))
fi

echo ""

# ----------------------------------------------------------------
# Check 3: Phase 1 Completion
# ----------------------------------------------------------------
echo "🎯 Check 3: Phase 1 Data"
echo "-------------------------------------"

# Check if any projects exist
PROJECT_COUNT=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_projects;" 2>/dev/null | tr -d ' ')

if [ "$PROJECT_COUNT" -gt 0 ]; then
    echo "✅ Found $PROJECT_COUNT project(s) in database"
    ((PASS_COUNT++))
else
    echo "❌ No projects found. Run Phase 1 workflow first."
    ((FAIL_COUNT++))
fi

# Check if any projects ready for Phase 2
READY_COUNT=$(docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT COUNT(*) FROM foundry_projects WHERE status = 'phase1_complete';" 2>/dev/null | tr -d ' ')

if [ "$READY_COUNT" -gt 0 ]; then
    echo "✅ Found $READY_COUNT project(s) ready for Phase 2 (status = 'phase1_complete')"
    ((PASS_COUNT++))
    
    # Show project names
    echo ""
    echo "   Projects ready for architecture:"
    docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT '   • ' || project_name || ' (ID: ' || id || ')' FROM foundry_projects WHERE status = 'phase1_complete' ORDER BY created_at;" 2>/dev/null
    echo ""
else
    echo "⚠️  No projects with status 'phase1_complete'"
    echo "   Either:"
    echo "   1. Run Phase 1 workflow to create new projects, OR"
    echo "   2. All existing projects already processed by Phase 2"
    ((WARN_COUNT++))
    
    # Show current project statuses
    echo ""
    echo "   Current project statuses:"
    docker exec foundry_db psql -U foundry -d foundry -t -c "SELECT '   • ' || status || ': ' || COUNT(*) || ' project(s)' FROM foundry_projects GROUP BY status;" 2>/dev/null
    echo ""
fi

# ----------------------------------------------------------------
# Check 4: n8n Accessibility
# ----------------------------------------------------------------
echo "🌐 Check 4: n8n Accessibility"
echo "-------------------------------------"

N8N_PORT=$(docker port foundry_n8n 5678 2>/dev/null | cut -d: -f2 || echo "5678")

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$N8N_PORT/healthz" | grep -q "200"; then
    echo "✅ n8n is accessible at http://localhost:$N8N_PORT"
    ((PASS_COUNT++))
else
    echo "⚠️  n8n health check failed (but container is running)"
    echo "   Try accessing: http://localhost:$N8N_PORT"
    ((WARN_COUNT++))
fi

echo ""

# ----------------------------------------------------------------
# Check 5: Workflow Files Present
# ----------------------------------------------------------------
echo "📋 Check 5: Workflow Files"
echo "-------------------------------------"

if [ -f "foundry_phase2_architecture_workflow.json" ]; then
    echo "✅ Phase 2 workflow JSON found"
    ((PASS_COUNT++))
    
    # Validate JSON syntax
    if command -v jq > /dev/null 2>&1; then
        if jq empty foundry_phase2_architecture_workflow.json > /dev/null 2>&1; then
            echo "✅ Workflow JSON is valid"
            ((PASS_COUNT++))
        else
            echo "❌ Workflow JSON has syntax errors"
            ((FAIL_COUNT++))
        fi
    else
        echo "⚠️  jq not installed (cannot validate JSON syntax)"
        ((WARN_COUNT++))
    fi
else
    echo "❌ foundry_phase2_architecture_workflow.json not found"
    ((FAIL_COUNT++))
fi

echo ""

# ----------------------------------------------------------------
# Check 6: Ollama (for future Phase 3)
# ----------------------------------------------------------------
echo "🤖 Check 6: Ollama (Phase 3 preparation)"
echo "-------------------------------------"

if docker ps | grep -q "foundry_ollama"; then
    echo "✅ foundry_ollama is running"
    ((PASS_COUNT++))
    
    # Check if qwen2.5-coder model is available
    if docker exec foundry_ollama ollama list 2>/dev/null | grep -q "qwen2.5-coder"; then
        echo "✅ qwen2.5-coder model found (ready for Phase 3)"
        ((PASS_COUNT++))
    else
        echo "⚠️  qwen2.5-coder model not found (needed for Phase 3 only)"
        echo "   To install: docker exec foundry_ollama ollama pull qwen2.5-coder:7b"
        ((WARN_COUNT++))
    fi
else
    echo "⚠️  foundry_ollama not running (needed for Phase 3 only)"
    ((WARN_COUNT++))
fi

echo ""

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
echo "====================================="
echo "📊 VALIDATION SUMMARY"
echo "====================================="
echo ""
echo "✅ Passed:   $PASS_COUNT"
echo "⚠️  Warnings: $WARN_COUNT"
echo "❌ Failed:   $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "🎉 ALL CRITICAL CHECKS PASSED"
    echo ""
    echo "✅ READY TO PROCEED WITH PHASE 2 IMPORT"
    echo ""
    echo "Next steps:"
    echo "1. Open n8n: http://localhost:$N8N_PORT"
    echo "2. Import: foundry_phase2_architecture_workflow.json"
    echo "3. Link credentials (Gemini + Postgres)"
    echo "4. Activate workflow"
    echo ""
    exit 0
else
    echo "❌ CRITICAL ISSUES FOUND"
    echo ""
    echo "Please resolve the failed checks above before importing Phase 2."
    echo ""
    echo "Common fixes:"
    echo "• Start containers: docker-compose up -d"
    echo "• Initialize DB: docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql"
    echo "• Run Phase 1: Execute Phase 1 workflow in n8n"
    echo ""
    exit 1
fi

# ================================================================
# END OF VALIDATION
# ================================================================
