-- Secure Views Migration
-- Fix for "Phantom Balance" issue where views were bypassing RLS

-- Enable security_invoker on all views so they run with the permissions 
-- of the user querying them (respecting RLS), rather than the view owner.

-- Accounts (used by BudgetService for Total Balance)
ALTER VIEW accounts SET (security_invoker = true);

-- Transactions
ALTER VIEW transactions SET (security_invoker = true);

-- Items
ALTER VIEW items SET (security_invoker = true);

-- Assets
ALTER VIEW assets SET (security_invoker = true);

-- Profiles
ALTER VIEW profiles SET (security_invoker = true);

-- Institutions (Public reference data, but good practice)
ALTER VIEW institutions SET (security_invoker = true);
