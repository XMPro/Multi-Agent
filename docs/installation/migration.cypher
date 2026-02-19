//Run these in order: Step 1 → Step 2A → Step 2B → Step 3

// Step 1: Check How Many Need Migration (Pre-Check)

// Count entries that will be affected by migration (excluding Wizard)
MATCH (e:Entry)
WHERE e.type <> 'Wizard'
RETURN 
    count(CASE WHEN e.id IS NOT NULL AND e.entry_id IS NOT NULL THEN 1 END) as will_remove_id,
    count(CASE WHEN e.id IS NOT NULL AND e.entry_id IS NULL THEN 1 END) as will_copy_id_to_entry_id,
    count(CASE WHEN e.id IS NULL AND e.entry_id IS NOT NULL THEN 1 END) as already_migrated,
    count(e) as total_non_wizard_entries

//**Expected output:**
//- `will_remove_id`: ~5,111 (entries that have both, will remove `id`)
//- `will_copy_id_to_entry_id`: 0 (entries missing `entry_id`, will copy from `id`)
//- `already_migrated`: ~1,286 (entries already correct)
//- `total_non_wizard_entries`: ~6,397

//Step 2: Run Migration Scripts
//Script 2A: Copy id to entry_id (if needed)

// Fix entries missing entry_id (should be 0 based on your data)
MATCH (e:Entry)
WHERE e.entry_id IS NULL 
  AND e.id IS NOT NULL 
  AND e.type <> 'Wizard'
SET e.entry_id = e.id
RETURN count(e) as entries_fixed

//Script 2B: Remove id property

// Remove id property from all non-Wizard entries
MATCH (e:Entry)
WHERE e.id IS NOT NULL 
  AND e.entry_id IS NOT NULL 
  AND e.type <> 'Wizard'
REMOVE e.id
RETURN count(e) as entries_cleaned
// Should return ~5,111

//Step 3: Verify Migration Complete (Post-Check)

// Verify all non-Wizard entries are migrated correctly
MATCH (e:Entry)
WHERE e.type <> 'Wizard'
RETURN 
    count(CASE WHEN e.id IS NOT NULL THEN 1 END) as still_have_id,
    count(CASE WHEN e.entry_id IS NULL THEN 1 END) as missing_entry_id,
    count(CASE WHEN e.id IS NULL AND e.entry_id IS NOT NULL THEN 1 END) as correctly_migrated,
    count(e) as total_non_wizard_entries

//Expected result:
//- `still_have_id`: **0** ✅
//- `missing_entry_id`: **0** ✅
//- `correctly_migrated`: **~6,397** ✅
//- `total_non_wizard_entries`: **~6,397** ✅


