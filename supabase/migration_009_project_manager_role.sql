-- Migration 009: Add project manager role support

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'members_role_check'
      AND conrelid = 'public.members'::regclass
  ) THEN
    ALTER TABLE public.members
    ADD CONSTRAINT members_role_check
    CHECK (role IS NULL OR role IN ('member', 'admin', 'superadmin', 'project_manager'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.is_project_manager()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT EXISTS (
    SELECT 1 FROM members m
    WHERE m.auth_id = auth.uid()
    AND m.role IN ('project_manager', 'admin', 'superadmin')
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_project_manager() TO authenticated;
