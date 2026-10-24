-- Business Rules to Executable Relational Model
-- Target: PostgreSQL 14+
-- Run this migration once against the target database.

BEGIN;

CREATE SCHEMA IF NOT EXISTS internship_mgmt;
SET search_path TO internship_mgmt, public;

CREATE TABLE IF NOT EXISTS students (
    student_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name        TEXT NOT NULL CHECK (length(trim(full_name)) > 0),
    email            TEXT NOT NULL CHECK (length(trim(email)) > 3),
    university       TEXT NOT NULL CHECK (length(trim(university)) > 0),
    department       TEXT NOT NULL CHECK (length(trim(department)) > 0),
    graduation_year  INTEGER NOT NULL CHECK (graduation_year BETWEEN 2000 AND 2100),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deactivated_at   TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_students_email_ci ON students (lower(email));

CREATE TABLE IF NOT EXISTS companies (
    company_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE CHECK (length(trim(name)) > 0),
    website          TEXT,
    contact_email    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deactivated_at   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS opportunities (
    opportunity_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id           BIGINT NOT NULL REFERENCES companies(company_id) ON DELETE RESTRICT,
    title                TEXT NOT NULL CHECK (length(trim(title)) > 0),
    description          TEXT NOT NULL DEFAULT '',
    location             TEXT NOT NULL DEFAULT 'Not specified',
    work_mode            TEXT NOT NULL DEFAULT 'hybrid'
                         CHECK (work_mode IN ('onsite', 'hybrid', 'remote')),
    status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'open', 'paused', 'closed')),
    openings             INTEGER NOT NULL DEFAULT 1 CHECK (openings > 0),
    application_open_at  TIMESTAMPTZ NOT NULL,
    application_close_at TIMESTAMPTZ NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (application_close_at > application_open_at),
    UNIQUE (company_id, title)
);
CREATE INDEX IF NOT EXISTS ix_opportunities_status_close
    ON opportunities (status, application_close_at);

CREATE TABLE IF NOT EXISTS applications (
    application_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id     BIGINT NOT NULL REFERENCES students(student_id) ON DELETE RESTRICT,
    opportunity_id BIGINT NOT NULL REFERENCES opportunities(opportunity_id) ON DELETE RESTRICT,
    status         TEXT NOT NULL DEFAULT 'submitted'
                   CHECK (status IN ('submitted', 'under_review', 'accepted', 'rejected', 'withdrawn')),
    applied_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_application_student_opportunity UNIQUE (student_id, opportunity_id),
    -- Supports the composite FK from internships and proves the student/opportunity pair.
    CONSTRAINT uq_application_id_student UNIQUE (application_id, student_id)
);
CREATE INDEX IF NOT EXISTS ix_applications_opportunity_status
    ON applications (opportunity_id, status);
CREATE INDEX IF NOT EXISTS ix_applications_student_applied
    ON applications (student_id, applied_at DESC);

CREATE TABLE IF NOT EXISTS internships (
    internship_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE,
    student_id     BIGINT NOT NULL,
    start_date     DATE NOT NULL,
    end_date       DATE,
    status         TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'completed', 'terminated')),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_internships_application_student
        FOREIGN KEY (application_id, student_id)
        REFERENCES applications(application_id, student_id) ON DELETE RESTRICT,
    CONSTRAINT ck_internship_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_internship_status_dates CHECK (
        (status = 'active' AND end_date IS NULL)
        OR (status IN ('completed', 'terminated') AND end_date IS NOT NULL)
    )
);
-- PostgreSQL partial unique index: a student can have at most one active internship.
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_internship_per_student
    ON internships (student_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS application_status_history (
    history_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id BIGINT NOT NULL REFERENCES applications(application_id) ON DELETE RESTRICT,
    old_status     TEXT,
    new_status     TEXT NOT NULL,
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by     TEXT NOT NULL DEFAULT CURRENT_USER
);
CREATE INDEX IF NOT EXISTS ix_application_history_application_time
    ON application_status_history (application_id, changed_at);

-- Applications are only accepted while the opportunity is open and within its window.
-- The trigger also restricts application status transitions to an explicit state machine.
CREATE OR REPLACE FUNCTION guard_application_write()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_opportunity_status TEXT;
    v_open_at TIMESTAMPTZ;
    v_close_at TIMESTAMPTZ;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'submitted' THEN
            RAISE EXCEPTION 'A new application must start in submitted status.'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        IF NEW.student_id IS DISTINCT FROM OLD.student_id
           OR NEW.opportunity_id IS DISTINCT FROM OLD.opportunity_id THEN
            RAISE EXCEPTION 'Application student and opportunity are immutable.'
                USING ERRCODE = '23514';
        END IF;

        IF NEW.status IS DISTINCT FROM OLD.status THEN
            IF EXISTS (SELECT 1 FROM internships i WHERE i.application_id = OLD.application_id)
               AND NEW.status <> 'accepted' THEN
                RAISE EXCEPTION 'Application status cannot change away from accepted after an internship is created.'
                    USING ERRCODE = '23514';
            END IF;

            IF NOT (
                (OLD.status = 'submitted' AND NEW.status IN ('under_review', 'withdrawn')) OR
                (OLD.status = 'under_review' AND NEW.status IN ('accepted', 'rejected', 'withdrawn')) OR
                (OLD.status = 'accepted' AND NEW.status = 'withdrawn' AND
                    NOT EXISTS (SELECT 1 FROM internships i WHERE i.application_id = OLD.application_id))
            ) THEN
                RAISE EXCEPTION 'Invalid application status transition: % -> %.', OLD.status, NEW.status
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END IF;

    IF TG_OP = 'INSERT' OR NEW.opportunity_id IS DISTINCT FROM OLD.opportunity_id THEN
        SELECT o.status, o.application_open_at, o.application_close_at
          INTO v_opportunity_status, v_open_at, v_close_at
          FROM opportunities o
         WHERE o.opportunity_id = NEW.opportunity_id;

        IF NOT FOUND THEN
            -- The FK will also reject this; this makes the failure message more direct.
            RAISE EXCEPTION 'Opportunity % does not exist.', NEW.opportunity_id
                USING ERRCODE = '23503';
        END IF;

        IF v_opportunity_status <> 'open' OR CURRENT_TIMESTAMP < v_open_at OR CURRENT_TIMESTAMP > v_close_at THEN
            RAISE EXCEPTION 'Applications are only allowed while the opportunity is open and inside its application window.'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_application_write ON applications;
CREATE TRIGGER trg_guard_application_write
BEFORE INSERT OR UPDATE ON applications
FOR EACH ROW EXECUTE FUNCTION guard_application_write();

-- Create internship rows only for an accepted application and matching student.
CREATE OR REPLACE FUNCTION guard_internship_application()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_application_status TEXT;
BEGIN
    SELECT a.status
      INTO v_application_status
      FROM applications a
     WHERE a.application_id = NEW.application_id
       AND a.student_id = NEW.student_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Internship must reference an existing application for the same student.'
            USING ERRCODE = '23503';
    END IF;

    IF v_application_status <> 'accepted' THEN
        RAISE EXCEPTION 'An internship can only be created from an accepted application.'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_internship_application ON internships;
CREATE TRIGGER trg_guard_internship_application
BEFORE INSERT OR UPDATE OF application_id, student_id ON internships
FOR EACH ROW EXECUTE FUNCTION guard_internship_application();

-- Append-only status audit trail. Initial status is recorded with old_status = NULL.
CREATE OR REPLACE FUNCTION record_application_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO application_status_history (application_id, old_status, new_status)
        VALUES (NEW.application_id, NULL, NEW.status);
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO application_status_history (application_id, old_status, new_status)
        VALUES (NEW.application_id, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_record_application_status_change ON applications;
CREATE TRIGGER trg_record_application_status_change
AFTER INSERT OR UPDATE OF status ON applications
FOR EACH ROW EXECUTE FUNCTION record_application_status_change();

-- Audit history is append-only. Related records use RESTRICT FKs rather than cascading deletes.
CREATE OR REPLACE FUNCTION reject_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Audit/history rows cannot be updated or deleted.' USING ERRCODE = '23514';
END;
$$;
DROP TRIGGER IF EXISTS trg_history_no_update ON application_status_history;
CREATE TRIGGER trg_history_no_update
BEFORE UPDATE OR DELETE ON application_status_history
FOR EACH ROW EXECUTE FUNCTION reject_audit_mutation();

COMMIT;
