-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: Add Call Tracking Fields to follow_ups
-- ═══════════════════════════════════════════════════════════════════════════

-- Add call tracking columns
ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_attempts INTEGER DEFAULT 0;
ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS last_call_at TIMESTAMPTZ;
ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_outcome TEXT; -- 'answered', 'no_answer', 'busy', 'voicemail', 'wrong_number'
ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_notes TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: Add Department to Custom Fields
-- ═══════════════════════════════════════════════════════════════════════════

-- Add department_id column to dynamic_field_definitions
ALTER TABLE dynamic_field_definitions ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_dfd_department ON dynamic_field_definitions(department_id);

COMMENT ON COLUMN follow_ups.call_attempts IS 'Number of call attempts made';
COMMENT ON COLUMN follow_ups.last_call_at IS 'Timestamp of last call attempt';
COMMENT ON COLUMN follow_ups.call_outcome IS 'Outcome of the last call: answered, no_answer, busy, voicemail, wrong_number';
COMMENT ON COLUMN follow_ups.call_notes IS 'Notes from the call';
COMMENT ON COLUMN dynamic_field_definitions.department_id IS 'Optional: Limit this field to a specific department';
