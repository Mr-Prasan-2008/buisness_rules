-- Repeatable demo fixtures for internship_mgmt.
-- WARNING: This resets data in the internship_mgmt project tables only.
BEGIN;
SET search_path TO internship_mgmt, public;

TRUNCATE TABLE
    application_status_history,
    internships,
    applications,
    opportunities,
    companies,
    students
RESTART IDENTITY CASCADE;

INSERT INTO students (full_name, email, university, department, graduation_year)
VALUES
    ('Asha Raman', 'asha.raman@example.edu', 'Example Institute of Technology', 'Data Science', 2028),
    ('Rahul Iyer', 'rahul.iyer@example.edu', 'Example Institute of Technology', 'Computer Science', 2028);

INSERT INTO companies (name, website, contact_email)
VALUES
    ('Acme Analytics', 'https://example.com/acme', 'careers@acme.example'),
    ('Northstar Labs', 'https://example.com/northstar', 'talent@northstar.example');

-- Relative time windows keep the open listings usable whenever fixtures are loaded.
INSERT INTO opportunities (
    company_id, title, description, location, work_mode, status, openings,
    application_open_at, application_close_at
)
SELECT c.company_id, x.title, x.description, x.location, x.work_mode, x.status, x.openings,
       CURRENT_TIMESTAMP - INTERVAL '30 days', CURRENT_TIMESTAMP + INTERVAL '30 days'
FROM (VALUES
    ('Acme Analytics', 'Data Science Intern', 'Analyze datasets and build reports.', 'Chennai, India', 'hybrid', 'open', 2),
    ('Northstar Labs', 'Backend Engineering Intern', 'Build and test API services.', 'Remote', 'remote', 'open', 1),
    ('Acme Analytics', 'Closed Analyst Internship', 'A closed example opportunity for negative testing.', 'Chennai, India', 'onsite', 'closed', 1)
) AS x(company_name, title, description, location, work_mode, status, openings)
JOIN companies c ON c.name = x.company_name;

-- First create three submitted applications. Two for Asha will be accepted;
-- Rahul's application remains submitted for the negative test.
INSERT INTO applications (student_id, opportunity_id, status)
SELECT s.student_id, o.opportunity_id, 'submitted'
FROM students s
JOIN (VALUES
    ('asha.raman@example.edu', 'Data Science Intern', 'Acme Analytics'),
    ('asha.raman@example.edu', 'Backend Engineering Intern', 'Northstar Labs'),
    ('rahul.iyer@example.edu', 'Data Science Intern', 'Acme Analytics')
) AS x(email, opportunity_title, company_name) ON x.email = s.email
JOIN opportunities o ON o.title = x.opportunity_title
JOIN companies c ON c.company_id = o.company_id AND c.name = x.company_name;

-- Advance Asha's applications through the allowed state machine. This creates
-- six history rows for her applications plus one initial row for Rahul.
UPDATE applications a
SET status = 'under_review'
FROM students s, opportunities o, companies c
WHERE a.student_id = s.student_id
  AND a.opportunity_id = o.opportunity_id
  AND o.company_id = c.company_id
  AND s.email = 'asha.raman@example.edu'
  AND c.name = 'Acme Analytics'
  AND o.title = 'Data Science Intern';

UPDATE applications a
SET status = 'accepted'
FROM students s, opportunities o, companies c
WHERE a.student_id = s.student_id
  AND a.opportunity_id = o.opportunity_id
  AND o.company_id = c.company_id
  AND s.email = 'asha.raman@example.edu'
  AND c.name = 'Acme Analytics'
  AND o.title = 'Data Science Intern';

UPDATE applications a
SET status = 'under_review'
FROM students s, opportunities o, companies c
WHERE a.student_id = s.student_id
  AND a.opportunity_id = o.opportunity_id
  AND o.company_id = c.company_id
  AND s.email = 'asha.raman@example.edu'
  AND c.name = 'Northstar Labs'
  AND o.title = 'Backend Engineering Intern';

UPDATE applications a
SET status = 'accepted'
FROM students s, opportunities o, companies c
WHERE a.student_id = s.student_id
  AND a.opportunity_id = o.opportunity_id
  AND o.company_id = c.company_id
  AND s.email = 'asha.raman@example.edu'
  AND c.name = 'Northstar Labs'
  AND o.title = 'Backend Engineering Intern';

-- One active internship for Asha. The accepted Backend application remains
-- available to confirm that a second active internship is rejected.
INSERT INTO internships (application_id, student_id, start_date, end_date, status)
SELECT a.application_id, a.student_id, CURRENT_DATE - 7, NULL, 'active'
FROM applications a
JOIN students s ON s.student_id = a.student_id
JOIN opportunities o ON o.opportunity_id = a.opportunity_id
JOIN companies c ON c.company_id = o.company_id
WHERE s.email = 'asha.raman@example.edu'
  AND c.name = 'Acme Analytics'
  AND o.title = 'Data Science Intern';

COMMIT;

\echo 'Seed fixture summary (expected: 2 students, 2 companies, 3 opportunities, 3 applications, 1 internship, 7 history rows):'
SELECT 'students' AS table_name, count(*) AS row_count FROM internship_mgmt.students
UNION ALL SELECT 'companies', count(*) FROM internship_mgmt.companies
UNION ALL SELECT 'opportunities', count(*) FROM internship_mgmt.opportunities
UNION ALL SELECT 'applications', count(*) FROM internship_mgmt.applications
UNION ALL SELECT 'internships', count(*) FROM internship_mgmt.internships
UNION ALL SELECT 'application_status_history', count(*) FROM internship_mgmt.application_status_history
ORDER BY table_name;
