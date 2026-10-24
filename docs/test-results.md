# Test Results and Execution Evidence

## Environment

- Database: PostgreSQL 16.15 (reported by the project owner as installed locally).
- Client: `psql` from Windows PowerShell.
- Database used: `internship_db`.
- Test script: `tests/negative_sql_tests.sql`, run after the schema migration and sample fixtures.
- Evidence source: console output pasted by the project owner during execution on 22 October 2026.

## Outcome summary

**All six negative-test cases printed `PASS` and reported the expected SQLSTATE.** The output also displayed the final demonstration-data row counts shown below.

| Test | Invalid operation | Expected SQLSTATE | Observed output |
|---|---|---:|---|
| R1 | Duplicate application for the same student and opportunity | `23505` | PASS |
| R2 | Application to a closed opportunity | `23514` | PASS |
| R3 | Creating an internship from a non-accepted application | `23514` | PASS |
| R4 | Creating a second active internship for the same student | `23505` | PASS |
| R5 | Internship end date earlier than start date | `23514` | PASS |
| RI | Application referencing a nonexistent student | `23503` | PASS |

## Observed row-count summary

This is transcribed from the user's PostgreSQL output:

| Table | Row count |
|---|---:|
| `application_status_history` | 7 |
| `applications` | 3 |
| `companies` | 2 |
| `internships` | 1 |
| `opportunities` | 3 |
| `students` | 2 |
| **Total table rows counted across these tables** | **18** |

The `18` total is the arithmetic sum across six independent tables; it is not a count of unique business entities.

## Captured output excerpts

```text
NOTICE:  PASS: R1 duplicate application is rejected (rejected with SQLSTATE 23505)
NOTICE:  PASS: R2 application to a closed opportunity is rejected (rejected with SQLSTATE 23514)
NOTICE:  PASS: R3 internship from non-accepted application is rejected (rejected with SQLSTATE 23514)
NOTICE:  PASS: R4 second active internship for the same student is rejected (rejected with SQLSTATE 23505)
NOTICE:  PASS: R5 internship end date before start date is rejected (rejected with SQLSTATE 23514)
NOTICE:  PASS: FK orphan student reference is rejected (rejected with SQLSTATE 23503)

DROP FUNCTION
          section           | row_count
----------------------------+-----------
 application_status_history | 7
 applications               | 3
 companies                  | 2
 internships                | 1
 opportunities              | 3
 students                   | 2
(6 rows)
```

The earlier full-run output also displayed the row-count table with the same six counts.

## About the PowerShell `NativeCommandError` display

The pasted PowerShell output included a `NativeCommandError` wrapper near the first PostgreSQL `NOTICE`. PostgreSQL `NOTICE` messages may be written to the native process's standard-error stream, which PowerShell can display in its error presentation. The key evidence here is that all six tests emitted their expected `PASS` notices and the script continued through cleanup and the count summary. This report does **not** claim a separately captured `$LASTEXITCODE`, because that value was not included in the supplied output.

To capture a clean exit-code check during a fresh run, use this from the repository root:

```powershell
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\tests\negative_sql_tests.sql"
$psqlExitCode = $LASTEXITCODE
Write-Host "psql exit code: $psqlExitCode"
if ($psqlExitCode -ne 0) { throw "The SQL test command returned a non-zero exit code." }
```

## Reproduce the full workflow

From the repository root, and only against the project's demo database:

```powershell
psql -U postgres -h localhost -p 5432 -d internship_db -v ON_ERROR_STOP=1 -f ".\tests\run_tests.sql"
```

The runner reloads the project fixture records. Do not run it in a database that contains information you need to preserve.
