-- ================================================================
-- FOUNDRY PHASE 2 - MANUAL DATABASE OPERATIONS
-- ================================================================
-- Use these if n8n nodes are giving errors
-- Run: docker exec -it foundry_db psql -U foundry -d foundry
-- ================================================================

-- ----------------------------------------------------------------
-- DIAGNOSTIC: Check Current State
-- ----------------------------------------------------------------

-- 1. Check what projects are ready for Phase 2
SELECT 
    id,
    project_name,
    status,
    created_at
FROM foundry_projects
WHERE status = 'phase1_complete'
ORDER BY created_at ASC;

-- 2. Check existing blueprints (to avoid duplicates)
SELECT 
    bp.project_id,
    p.project_name,
    bp.blueprint_type,
    bp.created_at
FROM foundry_blueprints bp
JOIN foundry_projects p ON p.id = bp.project_id
ORDER BY bp.project_id, bp.blueprint_type;

-- ----------------------------------------------------------------
-- FIX 1: Clean Slate (if needed)
-- ----------------------------------------------------------------

-- CAUTION: This deletes all blueprints and resets projects to phase1_complete
-- Only use if you want to start fresh

-- Uncomment to execute:
-- DELETE FROM foundry_blueprints;
-- UPDATE foundry_projects SET status = 'phase1_complete' WHERE status = 'phase2_complete';
-- DELETE FROM foundry_agent_log WHERE agent_role = 'architect';

-- ----------------------------------------------------------------
-- FIX 2: Recreate Tables with Correct Schema
-- ----------------------------------------------------------------

-- Drop existing tables (CAUTION: Loses all data)
DROP TABLE IF EXISTS foundry_blueprints CASCADE;
DROP TABLE IF EXISTS foundry_agent_log CASCADE;

-- Recreate with correct types
CREATE TABLE foundry_blueprints (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES foundry_projects(id) ON DELETE CASCADE,
    blueprint_type VARCHAR(50) NOT NULL,
    content JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_blueprint_project ON foundry_blueprints(project_id);
CREATE INDEX idx_blueprint_type ON foundry_blueprints(blueprint_type);

CREATE TABLE foundry_agent_log (
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

CREATE INDEX idx_log_project ON foundry_agent_log(project_id);
CREATE INDEX idx_log_agent ON foundry_agent_log(agent_role);
CREATE INDEX idx_log_created ON foundry_agent_log(created_at DESC);

-- ----------------------------------------------------------------
-- FIX 3: Test Insert (Manual Simulation of Phase 2)
-- ----------------------------------------------------------------

-- Step 1: Get a test project
DO $$
DECLARE
    test_project_id INTEGER;
BEGIN
    -- Find project ready for Phase 2
    SELECT id INTO test_project_id
    FROM foundry_projects
    WHERE status = 'phase1_complete'
    LIMIT 1;
    
    IF test_project_id IS NULL THEN
        RAISE NOTICE 'No projects ready for Phase 2';
    ELSE
        RAISE NOTICE 'Using project ID: %', test_project_id;
        
        -- Insert test blueprints
        INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
        VALUES 
            (test_project_id, 'file_tree', '{"root": "test_project", "structure": [{"path": "src/", "type": "directory"}]}'::jsonb, 1),
            (test_project_id, 'architecture', '{"layers": [{"name": "API", "tech": "FastAPI"}]}'::jsonb, 1),
            (test_project_id, 'dependencies', '[{"name": "fastapi", "version": "0.104.1"}]'::jsonb, 1),
            (test_project_id, 'implementation_plan', '[{"phase": 1, "files": ["main.py"]}]'::jsonb, 1);
        
        -- Update project status
        UPDATE foundry_projects
        SET status = 'phase2_complete', updated_at = NOW()
        WHERE id = test_project_id;
        
        -- Log activity
        INSERT INTO foundry_agent_log (project_id, agent_role, action, input_data, output_data, model_used, success)
        VALUES (
            test_project_id,
            'architect',
            'generate_blueprints',
            '{"project": "test"}'::jsonb,
            '{"blueprints_created": 4}'::jsonb,
            'gemini-1.5-pro',
            true
        );
        
        RAISE NOTICE 'Successfully created blueprints for project %', test_project_id;
    END IF;
END $$;

-- Verify results
SELECT 
    p.id,
    p.project_name,
    p.status,
    COUNT(bp.id) as blueprint_count
FROM foundry_projects p
LEFT JOIN foundry_blueprints bp ON bp.project_id = p.id
WHERE p.status = 'phase2_complete'
GROUP BY p.id, p.project_name, p.status;

-- ----------------------------------------------------------------
-- FIX 4: Check for Specific Error Patterns
-- ----------------------------------------------------------------

-- Check data types
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'foundry_blueprints'
ORDER BY ordinal_position;

-- Check constraints
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    CASE
        WHEN con.contype = 'f' THEN 'Foreign Key'
        WHEN con.contype = 'p' THEN 'Primary Key'
        WHEN con.contype = 'u' THEN 'Unique'
        WHEN con.contype = 'c' THEN 'Check'
        ELSE 'Other'
    END AS constraint_description
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'foundry_blueprints';

-- Check indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'foundry_blueprints';

-- ----------------------------------------------------------------
-- FIX 5: Common n8n Insert Patterns
-- ----------------------------------------------------------------

-- Pattern 1: Simple insert (what n8n should be doing)
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
SELECT 
    1,  -- Replace with actual project_id
    'file_tree',
    '{"test": "data"}'::jsonb,
    1
WHERE NOT EXISTS (
    SELECT 1 FROM foundry_blueprints 
    WHERE project_id = 1 AND blueprint_type = 'file_tree'
);

-- Pattern 2: Insert with JSON validation
INSERT INTO foundry_blueprints (project_id, blueprint_type, content, version)
SELECT 
    1,
    'architecture',
    content_text::jsonb,  -- Explicit cast from text to jsonb
    1
FROM (SELECT '{"layers": []}'::text AS content_text) AS src
WHERE (content_text::jsonb) IS NOT NULL;

-- ----------------------------------------------------------------
-- VERIFICATION QUERIES
-- ----------------------------------------------------------------

-- 1. Count blueprints per project
SELECT 
    p.id,
    p.project_name,
    p.status,
    COUNT(bp.id) as blueprint_count,
    string_agg(bp.blueprint_type, ', ' ORDER BY bp.blueprint_type) as types
FROM foundry_projects p
LEFT JOIN foundry_blueprints bp ON bp.project_id = p.id
GROUP BY p.id, p.project_name, p.status
ORDER BY p.id;

-- 2. Check for missing blueprint types (should be 4 per project)
WITH expected_types AS (
    SELECT unnest(ARRAY['file_tree', 'architecture', 'dependencies', 'implementation_plan']) as type
),
project_types AS (
    SELECT 
        p.id,
        p.project_name,
        et.type as expected_type,
        bp.blueprint_type
    FROM foundry_projects p
    CROSS JOIN expected_types et
    LEFT JOIN foundry_blueprints bp ON bp.project_id = p.id AND bp.blueprint_type = et.type
    WHERE p.status = 'phase2_complete'
)
SELECT 
    id,
    project_name,
    expected_type,
    CASE WHEN blueprint_type IS NULL THEN '❌ MISSING' ELSE '✅ EXISTS' END as status
FROM project_types
ORDER BY id, expected_type;

-- 3. Validate JSONB content
SELECT 
    id,
    project_id,
    blueprint_type,
    jsonb_typeof(content) as content_type,
    jsonb_array_length(
        CASE 
            WHEN jsonb_typeof(content) = 'array' THEN content
            WHEN content ? 'structure' AND jsonb_typeof(content->'structure') = 'array' THEN content->'structure'
            ELSE NULL
        END
    ) as array_length
FROM foundry_blueprints
ORDER BY project_id, blueprint_type;

-- ----------------------------------------------------------------
-- CLEANUP (if needed)
-- ----------------------------------------------------------------

-- Remove duplicate blueprints (keep latest)
DELETE FROM foundry_blueprints
WHERE id NOT IN (
    SELECT MAX(id)
    FROM foundry_blueprints
    GROUP BY project_id, blueprint_type
);

-- Remove blueprints for non-existent projects
DELETE FROM foundry_blueprints
WHERE project_id NOT IN (SELECT id FROM foundry_projects);

-- Reset projects back to phase1 (to re-run Phase 2)
UPDATE foundry_projects
SET status = 'phase1_complete', updated_at = NOW()
WHERE id IN (
    SELECT DISTINCT project_id 
    FROM foundry_blueprints 
    WHERE blueprint_type = 'file_tree'
);

-- ================================================================
-- END OF MANUAL OPERATIONS
-- ================================================================
