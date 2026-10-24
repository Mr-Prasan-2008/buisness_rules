# Business Rules to Executable Relational Model

A PostgreSQL database project that turns business rules for a representative internship-management workflow into enforceable relational constraints, triggers, indexes, audit history, sample fixtures, and negative SQL tests.

> **Scope note:** The initial assignment screenshot listed expected deliverables but did not include the original narrative business brief. This repository therefore documents its assumptions and implements a representative internship-management scenario. Confirm the rules against your mentor's actual brief before treating this as a final domain match.

## Project status

- PostgreSQL schema and triggers: implemented in `migrations/001_initial_schema.sql`.
- Repeatable demonstration data: `fixtures/001_seed_data.sql`.
- Six negative SQL tests: `tests/negative_sql_tests.sql`.
- One-command test runner: `tests/run_tests.sql`.
- Database design and rule mapping: `docs/design.md`.
- ER diagram source: `docs/er-diagram.mmd` and rendered Markdown version: `docs/er-diagram.md`.
- Execution evidence supplied from the local PostgreSQL 16.15 run: `docs/test-results.md`.

## Features

1. Students, companies, internship opportunities, applications, internship records, and application-status history.
2. Primary keys, foreign keys, uniqueness rules, checks, partial indexes, and database triggers.
3. Application state-transition enforcement and application-window validation.
4. Internship creation only from an accepted application for the same student.
5. Append-only status-history audit trail.
6. Six negative tests that confirm invalid writes fail with expected PostgreSQL SQLSTATE codes.

## Requirements

- PostgreSQL 14 or newer (the author ran these tests using PostgreSQL 16.15).
- `psql` command-line client.
- A PostgreSQL role with permission to create tables, functions, triggers, and indexes in the target database.

## Run on Windows PowerShell

Open PowerShell in the repository root (the folder containing `README.md`). If you need to navigate there, replace the path below with your local repository path:

```powershell
Set-Location -LiteralPath "C:\path\to\internship_relational_model"
psql --version
```

Check that the PostgreSQL server is reachable:

```powershell
psql -U postgres -h localhost -p 5432 -d postgres -c "SHOW server_version;"
```

Create the `internship_db` database only if it does not already exist:

```powershell
$dbExists = psql -U postgres -h localhost -p 5432 -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'internship_db'"
if ($LASTEXITCODE -ne 0) { throw "Could not connect to PostgreSQL. Check the server, username, port, and password." }
if ($dbExists.Trim() -ne "1") {
    createdb -U postgres -h localhost -p 5432 internship_db
    if ($LASTEXITCODE -ne 0) { throw "Database creation failed." }
    Write-Host "Database internship_db created."
} else {
    Write-Host "Database internship_db already exists."
}
```

Run the complete setup and test workflow from the repository root:

```powershell
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\tests\run_tests.sql"
```

The runner applies the migration, reloads the demonstration fixtures, executes all six negative tests, displays the table row counts, and prints a final success message if the script completes. **The seed fixture truncates/reloads the project's demo tables. Do not run it against production or data you need to keep.**

### Run each stage separately

```powershell
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\migrations\001_initial_schema.sql"
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\fixtures\001_seed_data.sql"
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\tests\negative_sql_tests.sql"
```

### Inspect the sample data

```powershell
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.students ORDER BY student_id;"
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.companies ORDER BY company_id;"
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.opportunities ORDER BY opportunity_id;"
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.applications ORDER BY application_id;"
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.internships ORDER BY internship_id;"
psql -U postgres -h localhost -p 5432 -d internship_db -c "SELECT * FROM internship_mgmt.application_status_history ORDER BY history_id;"
```

## Business rules covered

| ID | Rule | Primary enforcement | Expected SQLSTATE in negative test |
|---|---|---|---|
| R1 | A student cannot apply to the same opportunity twice. | `UNIQUE (student_id, opportunity_id)` | `23505` — unique violation |
| R2 | A new application requires an open opportunity and a valid application window. | `guard_application_write()` trigger | `23514` — check/business-rule violation |
| R3 | An internship must derive from an accepted application for the same student. | Trigger plus composite foreign key | `23514` for non-accepted application |
| R4 | A student can have at most one active internship. | Partial unique index | `23505` — unique violation |
| R5 | Internship end date cannot precede its start date, and dates must fit status. | `CHECK` constraints | `23514` — check violation |
| RI | Orphan student references are rejected. | Foreign key | `23503` — foreign-key violation |

See [`docs/design.md`](docs/design.md) for the full relational design, cardinalities, state machine, retention approach, and assumptions. See [`docs/test-results.md`](docs/test-results.md) for the observed local test output supplied during this project session.

## Repository layout

```text
.
├── README.md
├── LICENSE
├── .gitignore
├── migrations/
│   └── 001_initial_schema.sql
├── fixtures/
│   └── 001_seed_data.sql
├── tests/
│   ├── run_tests.sql
│   └── negative_sql_tests.sql
└── docs/
    ├── design.md
    ├── er-diagram.mmd
    ├── er-diagram.md
    ├── test-results.md
    ├── github-setup.md
    └── submission-checklist.md
```

## Safety and limitations

- Fixture names, companies, and opportunities are illustrative sample data.
- This is a database demonstration, not a complete recruiting platform. Authentication, authorization, interviews, offer documents, and evaluations are out of scope.
- The rules should be validated against the actual brief before submission.
- Do not commit real credentials, personal data, or production database dumps.
