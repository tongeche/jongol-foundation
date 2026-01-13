-- Migration 011: Allow authenticated members to manage JPP data

DROP POLICY IF EXISTS "Authenticated can manage JPP batches" ON jpp_batches;
CREATE POLICY "Authenticated can manage JPP batches"
ON jpp_batches
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated can manage JPP daily logs" ON jpp_daily_log;
CREATE POLICY "Authenticated can manage JPP daily logs"
ON jpp_daily_log
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated can manage JPP weekly growth" ON jpp_weekly_growth;
CREATE POLICY "Authenticated can manage JPP weekly growth"
ON jpp_weekly_growth
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated can manage JPP expenses" ON jpp_expenses;
CREATE POLICY "Authenticated can manage JPP expenses"
ON jpp_expenses
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
