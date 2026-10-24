-- Negative SQL tests. Run after the migration and fixtures.
-- Each test passes only when PostgreSQL rejects the invalid write with the expected SQLSTATE.
SET search_path TO internship_mgmt, public;

CREATE OR REPLACE FUNCTION pg_temp.expect_sqlstate(p_sql TEXT, p_expected_state TEXT, p_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual_state TEXT;
    v_message TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_actual_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT;
        IF v_actual_state = p_expected_state THEN
            RAISE NOTICE 'PASS: % (rejected with SQLSTATE %)', p_label, v_actual_state;
            RETURN;
        ELSE
            RAISE EXCEPTION 'FAIL: %; expected SQLSTATE %, got %: %',
                p_label, p_expected_state, v_actual_state, v_message;
        END IF;
    END;
    RAISE EXCEPTION 'FAIL: %; invalid statement unexpectedly succeeded.', p_label;
END;
$$;

-- R1: A student cannot apply to the same opportunity twice.
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO applications (student_id, opportunity_id, status)
    SELECT s.student_id, o.opportunity_id, 'submitted'
    FROM students s CROSS JOIN opportunities o JOIN companies c ON c.company_id = o.company_id
    WHERE s.email = 'asha.raman@example.edu'
      AND c.name = 'Acme Analytics' AND o.title = 'Data Science Intern'
$sql$, '23505', 'R1 duplicate application is rejected');

-- R2: An application to a closed opportunity is rejected by the business-rule trigger.
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO applications (student_id, opportunity_id, status)
    SELECT s.student_id, o.opportunity_id, 'submitted'
    FROM students s CROSS JOIN opportunities o JOIN companies c ON c.company_id = o.company_id
    WHERE s.email = 'rahul.iyer@example.edu'
      AND c.name = 'Acme Analytics' AND o.title = 'Closed Analyst Internship'
$sql$, '23514', 'R2 application to a closed opportunity is rejected');

-- R3: A submitted (not accepted) application cannot produce an internship.
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO internships (application_id, student_id, start_date, end_date, status)
    SELECT a.application_id, a.student_id, CURRENT_DATE, NULL, 'active'
    FROM applications a JOIN students s ON s.student_id = a.student_id
    JOIN opportunities o ON o.opportunity_id = a.opportunity_id
    WHERE s.email = 'rahul.iyer@example.edu' AND o.title = 'Data Science Intern'
$sql$, '23514', 'R3 internship from non-accepted application is rejected');

-- R4: Asha already has one active internship; her other accepted application cannot create a second.
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO internships (application_id, student_id, start_date, end_date, status)
    SELECT a.application_id, a.student_id, CURRENT_DATE, NULL, 'active'
    FROM applications a JOIN students s ON s.student_id = a.student_id
    JOIN opportunities o ON o.opportunity_id = a.opportunity_id
    WHERE s.email = 'asha.raman@example.edu' AND o.title = 'Backend Engineering Intern'
$sql$, '23505', 'R4 second active internship for the same student is rejected');

-- R5: End date cannot be earlier than start date (the status/date check is otherwise valid).
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO internships (application_id, student_id, start_date, end_date, status)
    SELECT a.application_id, a.student_id, DATE '2026-10-20', DATE '2026-10-01', 'completed'
    FROM applications a JOIN students s ON s.student_id = a.student_id
    JOIN opportunities o ON o.opportunity_id = a.opportunity_id
    WHERE s.email = 'asha.raman@example.edu' AND o.title = 'Backend Engineering Intern'
$sql$, '23514', 'R5 internship end date before start date is rejected');

-- Referential integrity: orphan student reference is rejected by the FK.
SELECT pg_temp.expect_sqlstate($sql$
    INSERT INTO applications (student_id, opportunity_id, status)
    SELECT 999999999, o.opportunity_id, 'submitted'
    FROM opportunities o JOIN companies c ON c.company_id = o.company_id
    WHERE c.name = 'Acme Analytics' AND o.title = 'Data Science Intern'
$sql$, '23503', 'FK orphan student reference is rejected');

DROP FUNCTION pg_temp.expect_sqlstate(TEXT, TEXT, TEXT);

-- Show current test fixtures and the audit trail for manual inspection.
SELECT 'students' AS section, count(*)::TEXT AS row_count FROM students
UNION ALL SELECT 'companies', count(*)::TEXT FROM companies
UNION ALL SELECT 'opportunities', count(*)::TEXT FROM opportunities
UNION ALL SELECT 'applications', count(*)::TEXT FROM applications
UNION ALL SELECT 'internships', count(*)::TEXT FROM internships
UNION ALL SELECT 'application_status_history', count(*)::TEXT FROM application_status_history
ORDER BY section;
