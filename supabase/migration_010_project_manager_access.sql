-- Migration 010: Project manager access for project data

-- JPP tables
ALTER TABLE jpp_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE jpp_daily_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE jpp_weekly_growth ENABLE ROW LEVEL SECURITY;
ALTER TABLE jpp_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view JPP batches" ON jpp_batches;
CREATE POLICY "Authenticated can view JPP batches"
ON jpp_batches
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Project managers can manage JPP batches" ON jpp_batches;
CREATE POLICY "Project managers can manage JPP batches"
ON jpp_batches
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Authenticated can view JPP daily logs" ON jpp_daily_log;
CREATE POLICY "Authenticated can view JPP daily logs"
ON jpp_daily_log
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Project managers can manage JPP daily logs" ON jpp_daily_log;
CREATE POLICY "Project managers can manage JPP daily logs"
ON jpp_daily_log
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Authenticated can view JPP weekly growth" ON jpp_weekly_growth;
CREATE POLICY "Authenticated can view JPP weekly growth"
ON jpp_weekly_growth
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Project managers can manage JPP weekly growth" ON jpp_weekly_growth;
CREATE POLICY "Project managers can manage JPP weekly growth"
ON jpp_weekly_growth
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Authenticated can view JPP expenses" ON jpp_expenses;
CREATE POLICY "Authenticated can view JPP expenses"
ON jpp_expenses
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Project managers can manage JPP expenses" ON jpp_expenses;
CREATE POLICY "Project managers can manage JPP expenses"
ON jpp_expenses
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

-- IGA projects and related tables
ALTER TABLE iga_projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow admins to manage projects" ON iga_projects;
CREATE POLICY "Project managers can manage projects"
ON iga_projects
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Admins can manage project goals" ON project_goals;
CREATE POLICY "Project managers can manage project goals"
ON project_goals
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Admins can manage volunteer roles" ON project_volunteer_roles;
CREATE POLICY "Project managers can manage volunteer roles"
ON project_volunteer_roles
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Admins can manage project gallery" ON project_gallery;
CREATE POLICY "Project managers can manage project gallery"
ON project_gallery
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Public can view project FAQ" ON project_faq;
CREATE POLICY "Public can view project FAQ" ON project_faq
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Project managers can manage project FAQ" ON project_faq;
CREATE POLICY "Project managers can manage project FAQ"
ON project_faq
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Public can view project activities" ON project_activities;
CREATE POLICY "Public can view project activities" ON project_activities
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Project managers can manage project activities" ON project_activities;
CREATE POLICY "Project managers can manage project activities"
ON project_activities
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());

DROP POLICY IF EXISTS "Public can view donation items" ON project_donation_items;
CREATE POLICY "Public can view donation items" ON project_donation_items
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Project managers can manage donation items" ON project_donation_items;
CREATE POLICY "Project managers can manage donation items"
ON project_donation_items
FOR ALL
TO authenticated
USING (public.is_project_manager())
WITH CHECK (public.is_project_manager());
