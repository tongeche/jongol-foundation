-- Migration 012: Create JGF (Groundnut Foods) Project Tables
-- Jongol Groundnut Foods tracking system

-- ============================================
-- JGF PRODUCTION BATCHES
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_batches (
    id SERIAL PRIMARY KEY,
    batch_code VARCHAR(50) NOT NULL,
    batch_name VARCHAR(255),
    product_type VARCHAR(100) NOT NULL, -- 'peanut_butter', 'roasted_nuts', 'groundnut_flour', etc.
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    raw_groundnuts_kg DECIMAL(10,2) DEFAULT 0,
    output_quantity_kg DECIMAL(10,2) DEFAULT 0,
    output_units INTEGER DEFAULT 0,
    unit_size_grams INTEGER DEFAULT 500, -- Size per unit (e.g., 500g jar)
    cost_raw_materials DECIMAL(12,2) DEFAULT 0,
    cost_processing DECIMAL(12,2) DEFAULT 0,
    cost_packaging DECIMAL(12,2) DEFAULT 0,
    cost_labour DECIMAL(12,2) DEFAULT 0,
    selling_price_per_unit DECIMAL(10,2) DEFAULT 0,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JGF INVENTORY
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_inventory (
    id SERIAL PRIMARY KEY,
    item_type VARCHAR(50) NOT NULL CHECK (item_type IN ('raw_material', 'product', 'packaging')),
    item_name VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,2) DEFAULT 0,
    unit VARCHAR(50) DEFAULT 'kg', -- 'kg', 'units', 'pieces', 'bags'
    unit_cost DECIMAL(10,2) DEFAULT 0,
    reorder_level DECIMAL(10,2) DEFAULT 0,
    supplier_name VARCHAR(255),
    supplier_contact VARCHAR(100),
    last_restocked DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JGF PRODUCTION LOGS
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_production_logs (
    id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES jgf_batches(id) ON DELETE CASCADE,
    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    groundnuts_processed_kg DECIMAL(10,2) DEFAULT 0,
    output_produced_kg DECIMAL(10,2) DEFAULT 0,
    units_packaged INTEGER DEFAULT 0,
    quality_grade VARCHAR(20), -- 'A', 'B', 'C' or 'premium', 'standard'
    wastage_kg DECIMAL(10,2) DEFAULT 0,
    workers_count INTEGER DEFAULT 0,
    hours_worked DECIMAL(5,2) DEFAULT 0,
    equipment_used TEXT,
    issues_notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JGF SALES
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_sales (
    id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES jgf_batches(id) ON DELETE SET NULL,
    sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
    product_type VARCHAR(100) NOT NULL,
    quantity_units INTEGER DEFAULT 0,
    quantity_kg DECIMAL(10,2) DEFAULT 0,
    unit_price DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(12,2) DEFAULT 0,
    customer_name VARCHAR(255),
    customer_contact VARCHAR(100),
    customer_type VARCHAR(50), -- 'retail', 'wholesale', 'distributor', 'institution'
    payment_status VARCHAR(20) DEFAULT 'paid' CHECK (payment_status IN ('pending', 'partial', 'paid')),
    payment_method VARCHAR(50), -- 'cash', 'mpesa', 'bank', 'credit'
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JGF EXPENSES
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_expenses (
    id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES jgf_batches(id) ON DELETE SET NULL,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category VARCHAR(50) NOT NULL, -- 'Raw Materials', 'Packaging', 'Labour', 'Equipment', 'Transport', 'Utilities', 'Marketing', 'Other'
    amount DECIMAL(12,2) NOT NULL,
    vendor VARCHAR(255),
    description TEXT,
    receipt_available BOOLEAN DEFAULT FALSE,
    approved_by UUID REFERENCES auth.users(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JGF SUPPLIER PURCHASES
-- ============================================
CREATE TABLE IF NOT EXISTS jgf_purchases (
    id SERIAL PRIMARY KEY,
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_name VARCHAR(255) NOT NULL,
    supplier_contact VARCHAR(100),
    item_type VARCHAR(50) NOT NULL, -- 'groundnuts', 'packaging', 'labels', 'jars', 'other'
    quantity DECIMAL(10,2) NOT NULL,
    unit VARCHAR(50) DEFAULT 'kg',
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    quality_grade VARCHAR(20),
    payment_status VARCHAR(20) DEFAULT 'paid' CHECK (payment_status IN ('pending', 'partial', 'paid')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_jgf_batches_status ON jgf_batches(status);
CREATE INDEX IF NOT EXISTS idx_jgf_batches_product_type ON jgf_batches(product_type);
CREATE INDEX IF NOT EXISTS idx_jgf_production_logs_batch ON jgf_production_logs(batch_id);
CREATE INDEX IF NOT EXISTS idx_jgf_production_logs_date ON jgf_production_logs(log_date);
CREATE INDEX IF NOT EXISTS idx_jgf_sales_date ON jgf_sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_jgf_sales_batch ON jgf_sales(batch_id);
CREATE INDEX IF NOT EXISTS idx_jgf_expenses_date ON jgf_expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_jgf_expenses_batch ON jgf_expenses(batch_id);
CREATE INDEX IF NOT EXISTS idx_jgf_purchases_date ON jgf_purchases(purchase_date);
CREATE INDEX IF NOT EXISTS idx_jgf_inventory_type ON jgf_inventory(item_type);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE jgf_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_production_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE jgf_purchases ENABLE ROW LEVEL SECURITY;

-- Policies for jgf_batches
CREATE POLICY "Allow authenticated read on jgf_batches" ON jgf_batches
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_batches" ON jgf_batches
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_inventory
CREATE POLICY "Allow authenticated read on jgf_inventory" ON jgf_inventory
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_inventory" ON jgf_inventory
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_production_logs
CREATE POLICY "Allow authenticated read on jgf_production_logs" ON jgf_production_logs
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_production_logs" ON jgf_production_logs
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_sales
CREATE POLICY "Allow authenticated read on jgf_sales" ON jgf_sales
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_sales" ON jgf_sales
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_expenses
CREATE POLICY "Allow authenticated read on jgf_expenses" ON jgf_expenses
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_expenses" ON jgf_expenses
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- Policies for jgf_purchases
CREATE POLICY "Allow authenticated read on jgf_purchases" ON jgf_purchases
    FOR SELECT TO authenticated USING (true);
    
CREATE POLICY "Allow admins and project_managers to manage jgf_purchases" ON jgf_purchases
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.auth_id = auth.uid() 
            AND members.role IN ('admin', 'superadmin', 'project_manager')
        )
    );

-- ============================================
-- VIEW FOR JGF BATCH KPIs
-- ============================================
CREATE OR REPLACE VIEW jgf_batch_kpis AS
SELECT 
    b.id,
    b.batch_code,
    b.batch_name,
    b.product_type,
    b.status,
    b.start_date,
    b.end_date,
    b.raw_groundnuts_kg,
    b.output_quantity_kg,
    b.output_units,
    b.unit_size_grams,
    COALESCE(b.cost_raw_materials, 0) + COALESCE(b.cost_processing, 0) + 
        COALESCE(b.cost_packaging, 0) + COALESCE(b.cost_labour, 0) AS total_batch_cost,
    b.selling_price_per_unit,
    COALESCE(SUM(s.total_amount), 0) AS total_revenue,
    COALESCE(SUM(s.quantity_units), 0) AS units_sold,
    b.output_units - COALESCE(SUM(s.quantity_units), 0) AS units_remaining,
    CASE 
        WHEN b.raw_groundnuts_kg > 0 THEN 
            ROUND((b.output_quantity_kg / b.raw_groundnuts_kg * 100)::numeric, 1)
        ELSE 0 
    END AS yield_percentage,
    COALESCE(SUM(e.amount), 0) AS total_expenses
FROM jgf_batches b
LEFT JOIN jgf_sales s ON s.batch_id = b.id
LEFT JOIN jgf_expenses e ON e.batch_id = b.id
GROUP BY b.id, b.batch_code, b.batch_name, b.product_type, b.status, b.start_date, 
         b.end_date, b.raw_groundnuts_kg, b.output_quantity_kg, b.output_units, 
         b.unit_size_grams, b.cost_raw_materials, b.cost_processing, 
         b.cost_packaging, b.cost_labour, b.selling_price_per_unit;

-- ============================================
-- SEED DATA: Initial Inventory Items
-- ============================================
INSERT INTO jgf_inventory (item_type, item_name, quantity, unit, unit_cost, reorder_level, notes)
VALUES 
    ('raw_material', 'Raw Groundnuts', 0, 'kg', 150, 50, 'Main raw material for all products'),
    ('raw_material', 'Sugar', 0, 'kg', 120, 10, 'For sweetened peanut butter'),
    ('raw_material', 'Salt', 0, 'kg', 50, 5, 'For salted products'),
    ('raw_material', 'Cooking Oil', 0, 'litres', 200, 5, 'For roasting'),
    ('packaging', 'Glass Jars 500g', 0, 'units', 45, 100, 'For peanut butter'),
    ('packaging', 'Plastic Containers 250g', 0, 'units', 25, 200, 'For roasted nuts'),
    ('packaging', 'Labels - Peanut Butter', 0, 'units', 5, 200, 'Product labels'),
    ('packaging', 'Labels - Roasted Nuts', 0, 'units', 5, 200, 'Product labels'),
    ('packaging', 'Carton Boxes', 0, 'units', 80, 50, 'For bulk packaging')
ON CONFLICT DO NOTHING;
