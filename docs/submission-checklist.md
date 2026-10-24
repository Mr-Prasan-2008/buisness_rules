# Submission Checklist

Use this list before sending the repository link to your internship mentor.

- [ ] Verify the five core business rules against the original internship brief.
- [ ] Confirm that the database/schema name and table names match any naming constraints from the mentor.
- [ ] Keep the SQL migration, fixtures, and negative tests in the repository.
- [ ] Confirm that the six negative tests each print `PASS` with the expected SQLSTATE.
- [ ] Capture a fresh process exit code if the mentor requires clean terminal test evidence.
- [ ] Review `docs/test-results.md`; it documents the output observed locally and does not invent a process exit code.
- [ ] Render and review the Mermaid ER diagram.
- [ ] Check that no credentials, personal data, `.env` files, or database dumps are staged for commit.
- [ ] Add all files, commit, and push to GitHub.
- [ ] Open the GitHub repository in a browser and verify that its README, diagram, SQL files, and report are accessible.
- [ ] Share the GitHub URL and a short summary with the mentor.

## Suggested submission message

> I have completed the PostgreSQL relational model for the documented internship-management scenario. The repository includes the schema migration, sample fixtures, ER diagram, business-rule-to-constraint mapping, negative SQL tests, and the locally observed test output. All six negative tests reported the expected rejection SQLSTATEs. I have documented the assumptions used because the full narrative brief was not present in the initial task screenshot.
