-- ================================================================
-- FOUNDRY DATABASE INITIALIZATION
-- Zero-Cost Engineering Workforce - Data Schema v2.1
-- ================================================================
-- Date: 2026-01-28
-- Purpose: Phase 1 (Intake) + Future Phases (Architecture, Coding)
-- ================================================================

-- ----------------------------------------------------------------
-- PHASE 1: EXECUTIVE INTAKE TABLES
-- ----------------------------------------------------------------

-- Main projects table (stores MRS + Stack Decision)
CREATE TABLE IF NOT EXISTS foundry_projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    description TEXT,
    mrs_data JSONB NOT NULL,
    stack_decision JSONB,
    status VARCHAR(50) DEFAULT 'intake',
    priority INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_project_status ON foundry_projects(status);
CREATE INDEX IF NOT EXISTS idx_project_priority ON foundry_projects(priority DESC);
CREATE INDEX IF NOT EXISTS idx_created_at ON foundry_projects(created_at DESC);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_foundry_projects_updated_at
    BEFORE UPDATE ON foundry_projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------
-- PHASE 2: ARCHITECTURE TABLES (Future)
-- ----------------------------------------------------------------

-- Blueprints table (file trees, tech specs)
CREATE TABLE IF NOT EXISTS foundry_blueprints (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    blueprint_type VARCHAR(50) NOT NULL, -- 'file_tree', 'api_spec', 'data_model'
    content JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blueprint_project ON foundry_blueprints(project_id);

-- ----------------------------------------------------------------
-- PHASE 3: CODE GENERATION TABLES (Future)
-- ----------------------------------------------------------------

-- Generated files tracking
CREATE TABLE IF NOT EXISTS foundry_files (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    file_path VARCHAR(500) NOT NULL,
    file_content TEXT NOT NULL,
    language VARCHAR(50),
    model_used VARCHAR(100), -- e.g., 'qwen2.5-coder:7b'
    status VARCHAR(50) DEFAULT 'generated', -- 'generated', 'tested', 'approved'
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_file_project ON foundry_files(project_id);
CREATE INDEX IF NOT EXISTS idx_file_status ON foundry_files(status);

-- ----------------------------------------------------------------
-- PHASE 4: TESTING & QA TABLES (Future)
-- ----------------------------------------------------------------

-- Test results storage
CREATE TABLE IF NOT EXISTS foundry_tests (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    test_type VARCHAR(50) NOT NULL, -- 'unit', 'integration', 'security'
    test_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'pass', 'fail', 'skip'
    error_message TEXT,
    execution_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_test_project ON foundry_tests(project_id);

-- ----------------------------------------------------------------
-- AGENT ACTIVITY LOG (Observability)
-- ----------------------------------------------------------------

-- Track all agent actions for debugging
CREATE TABLE IF NOT EXISTS foundry_agent_log (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    agent_role VARCHAR(50) NOT NULL, -- 'liaison', 'strategist', 'architect', etc.
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

-- ----------------------------------------------------------------
-- HELPER VIEWS
-- ----------------------------------------------------------------

-- Active projects overview
CREATE OR REPLACE VIEW v_active_projects AS
SELECT 
    id,
    project_name,
    status,
    priority,
    mrs_data->>'description' as description,
    stack_decision->'recommended_stack'->>'primary_language' as language,
    created_at,
    updated_at
FROM foundry_projects
WHERE status NOT IN ('completed', 'cancelled')
ORDER BY priority DESC, created_at DESC;

-- Project completion stats
CREATE OR REPLACE VIEW v_project_stats AS
SELECT 
    status,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))/3600)::DECIMAL(10,2) as avg_hours_to_complete
FROM foundry_projects
GROUP BY status;

-- ----------------------------------------------------------------
-- SEED DATA (For Testing)
-- ----------------------------------------------------------------

-- Insert a test project (optional - remove in production)
INSERT INTO foundry_projects (
    project_name,
    description,
    mrs_data,
    stack_decision,
    status
) VALUES (
    'Test Project: Hello World API',
    'A simple REST API for testing Phase 1',
    '{
        "project_name": "Hello World API",
        "description": "Basic REST API with GET /hello endpoint",
        "requirements": ["Return JSON response", "Handle CORS"],
        "constraints": {"budget": "R0", "timeline": "1 hour"},
        "success_criteria": ["API responds within 100ms", "No runtime errors"]
    }'::jsonb,
    '{
        "recommended_stack": {
            "primary_language": "Python",
            "framework": "FastAPI",
            "database": "SQLite",
            "reasoning": "FastAPI is lightweight, has automatic docs, and requires no configuration"
        },
        "alternative_stacks": []
    }'::jsonb,
    'intake'
) ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------
-- VERIFICATION QUERIES
-- ----------------------------------------------------------------

-- Check tables exist
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public' AND tablename LIKE 'foundry_%'
ORDER BY tablename;

-- Check indexes
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename LIKE 'foundry_%'
ORDER BY tablename, indexname;

-- ================================================================
-- READY FOR PRODUCTION
-- ================================================================
-- Run this script:
--   docker exec -i foundry_db psql -U foundry -d foundry < init_db.sql
-- Or interactively:
--   docker exec -it foundry_db psql -U foundry -d foundry
--   \i /path/to/init_db.sql
-- ================================================================
