-- Migration 013: Project expense items lookup (reusable across projects)

CREATE TABLE IF NOT EXISTS project_expense_items (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES iga_projects(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  category TEXT,
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_project_expense_items_project_label
  ON project_expense_items(project_id, label);

CREATE INDEX IF NOT EXISTS idx_project_expense_items_project_order
  ON project_expense_items(project_id, display_order);

ALTER TABLE project_expense_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view project expense items" ON project_expense_items;
CREATE POLICY "Authenticated can view project expense items"
  ON project_expense_items
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated can manage project expense items" ON project_expense_items;
CREATE POLICY "Authenticated can manage project expense items"
  ON project_expense_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Seed default expense items for JPP
INSERT INTO project_expense_items (project_id, label, category, display_order)
SELECT p.id, t.label, t.category, t.ord
FROM iga_projects p
JOIN LATERAL (
  SELECT *
  FROM unnest(
    ARRAY[
      'Layer feed (mash)',
      'Supplements (grit/oyster shell)',
      'Vitamins/minerals',
      'Vaccines/meds',
      'Litter/bedding',
      'Disinfectant/cleaning',
      'Egg trays/packaging',
      'Electricity',
      'Water',
      'Transport/fuel',
      'Repairs/maintenance',
      'Wages/labor',
      'Pest control',
      'Generator fuel/LPG',
      'Vet services',
      'Equipment replacement',
      'Waste disposal',
      'Security',
      'Phone/data',
      'Licenses/permits',
      'Insurance',
      'Bank/mobile money fees'
    ],
    ARRAY[
      'Feed',
      'Feed',
      'Meds',
      'Meds',
      'Bedding',
      'Other',
      'Other',
      'Utilities',
      'Utilities',
      'Transport',
      'Repairs',
      'Labour',
      'Other',
      'Utilities',
      'Meds',
      'Repairs',
      'Utilities',
      'Other',
      'Utilities',
      'Other',
      'Other',
      'Other'
    ]
  ) WITH ORDINALITY AS t(label, category, ord)
) t ON true
WHERE p.code = 'JPP'
ON CONFLICT (project_id, label) DO NOTHING;
