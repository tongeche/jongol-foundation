-- Migration 019: Drop legacy JGF sales table

-- Ensure data has been migrated into project_sales before running this.

drop table if exists jgf_sales;
