-- Migration 017: Drop legacy project expense tables

-- Ensure data has been migrated into project_expenses before running this.

drop table if exists jpp_expenses;
drop table if exists jgf_expenses;
