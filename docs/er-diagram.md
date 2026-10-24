# Entity–Relationship Diagram

The diagram below shows the project tables and their conceptual relationships. GitHub renders Mermaid diagrams in Markdown.

```mermaid
erDiagram
    STUDENTS ||--o{ APPLICATIONS : submits
    COMPANIES ||--o{ OPPORTUNITIES : publishes
    OPPORTUNITIES ||--o{ APPLICATIONS : receives
    APPLICATIONS ||--o| INTERNSHIPS : may_create
    APPLICATIONS ||--o{ APPLICATION_STATUS_HISTORY : records

    STUDENTS {
        bigint student_id PK
        text full_name
        text email UK
        text university
        text department
        int graduation_year
        timestamptz created_at
        timestamptz deactivated_at
    }
    COMPANIES {
        bigint company_id PK
        text name UK
        text website
        text contact_email
        timestamptz created_at
        timestamptz deactivated_at
    }
    OPPORTUNITIES {
        bigint opportunity_id PK
        bigint company_id FK
        text title
        text work_mode
        text status
        int openings
        timestamptz application_open_at
        timestamptz application_close_at
    }
    APPLICATIONS {
        bigint application_id PK
        bigint student_id FK
        bigint opportunity_id FK
        text status
        timestamptz applied_at
        timestamptz updated_at
    }
    INTERNSHIPS {
        bigint internship_id PK
        bigint application_id FK,UK
        bigint student_id FK
        date start_date
        date end_date
        text status
    }
    APPLICATION_STATUS_HISTORY {
        bigint history_id PK
        bigint application_id FK
        text old_status
        text new_status
        timestamptz changed_at
        text changed_by
    }
```

For the relational rules and cardinality explanations, see [the design report](design.md).
