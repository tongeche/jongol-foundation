-- Migration 014: JGF Farming and Land Management
-- Extends the JGF system to include farming activities and land rentals

-- ============================================
-- 1. LAND LEASES / RENTALS
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_land_leases (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- e.g. "Plot A - River Side"
    location VARCHAR(255),
    size_acres DECIMAL(5,2),
    lease_cost DECIMAL(12,2) DEFAULT 0,
    start_date DATE,
    end_date DATE,
    landowner_name VARCHAR(255),
    landowner_contact VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'expired', 'pending', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. CROP CYCLES / SEASONS
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_crop_cycles (
    id SERIAL PRIMARY KEY,
    lease_id INTEGER REFERENCES jgf_land_leases(id) ON DELETE SET NULL,
    cycle_name VARCHAR(100), -- "Season 1 2026 - Long Rains"
    crop_variety VARCHAR(100) DEFAULT 'Groundnuts', -- "Red Valencia", "Runner"
    start_date DATE,
    harvest_date DATE,
    status VARCHAR(50) DEFAULT 'planned' CHECK (status IN ('planned', 'land_prep', 'seeded', 'growing', 'harvesting', 'drying', 'completed', 'failed')),
    projected_yield_kg DECIMAL(10,2),
    actual_yield_kg DECIMAL(10,2),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. FARMING ACTIVITIES LOG
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_farming_activities (
    id SERIAL PRIMARY KEY,
    cycle_id INTEGER REFERENCES jgf_crop_cycles(id) ON DELETE CASCADE,
    activity_date DATE DEFAULT CURRENT_DATE,
    activity_type VARCHAR(50) NOT NULL, 
    -- e.g. 'clearing', 'ploughing', 'planting', 'weeding', 'spraying', 'fertilizing', 'harvesting', 'transport', 'post_harvest', 'scouting'
    description TEXT,
    labour_cost DECIMAL(10,2) DEFAULT 0,
    input_cost DECIMAL(10,2) DEFAULT 0, -- Cost of seeds, fertilizer used
    equipment_cost DECIMAL(10,2) DEFAULT 0, -- Tractor rental etc
    other_cost DECIMAL(10,2) DEFAULT 0,
    total_cost DECIMAL(12,2) GENERATED ALWAYS AS (labour_cost + input_cost + equipment_cost + other_cost) STORED,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. UPDATE INVENTORY TYPE CONSTRAINT
-- ============================================
-- We need to allow 'farming_input' in jgf_inventory.item_type
-- Note: 'pg_constraint' queries are complex to use purely SQL for idempotent updates on constraints sometimes, 
-- but we'll try standard ALTER TABLE DROP/ADD.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'jgf_inventory_item_type_check'
    ) THEN
        ALTER TABLE jgf_inventory DROP CONSTRAINT jgf_inventory_item_type_check;
    END IF;
END $$;

ALTER TABLE jgf_inventory ADD CONSTRAINT jgf_inventory_item_type_check 
    CHECK (item_type IN ('raw_material', 'product', 'packaging', 'farming_input', 'tool'));

-- ============================================
-- 5. INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_jgf_leases_status ON jgf_land_leases(status);
CREATE INDEX IF NOT EXISTS idx_jgf_cycles_status ON jgf_crop_cycles(status);
CREATE INDEX IF NOT EXISTS idx_jgf_activities_cycle ON jgf_farming_activities(cycle_id);
CREATE INDEX IF NOT EXISTS idx_jgf_activities_date ON jgf_farming_activities(activity_date);

-- ============================================
-- 6. RLS POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE jgf_land_leases ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_crop_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_farming_activities ENABLE ROW LEVEL SECURITY;

-- Policies for jgf_land_leases
CREATE POLICY "Allow authenticated read on jgf_land_leases" ON jgf_land_leases
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins/PMs manage jgf_land_leases" ON jgf_land_leases
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_crop_cycles
CREATE POLICY "Allow authenticated read on jgf_crop_cycles" ON jgf_crop_cycles
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins/PMs manage jgf_crop_cycles" ON jgf_crop_cycles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_farming_activities
CREATE POLICY "Allow authenticated read on jgf_farming_activities" ON jgf_farming_activities
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins/PMs manage jgf_farming_activities" ON jgf_farming_activities
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );
