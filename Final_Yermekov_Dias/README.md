# Final Project — University Domain

**Student:** Salamat Raiymbek  
**Database:** `university_db`  
**Schema:** `university`

## Domain Description

This database models a university academic management system.
Students enroll in course schedules taught by instructors across
different departments and faculties. Each enrollment can receive
a grade, and letter grades are automatically derived from the score.

## Files

| File | Description |
|------|-------------|
| `01_model.pdf` | Conceptual ERD + Logical Model |
| `02_final.sql` | Full database script |
| `README.md` | This file |

## How to Run

1. Open DBeaver (or pgAdmin)
2. Create a new database manually:
   ```sql
   CREATE DATABASE university_db;
   ```
3. Connect to `university_db`
4. Open `02_final.sql`
5. Select schema `university` in the toolbar
6. Press **Ctrl+A** to select all, then **Alt+X** to execute
7. Run the script a **second time** — it must complete with zero errors

## Database Structure

| Table | Description |
|-------|-------------|
| `faculties` | University faculties |
| `departments` | Departments belonging to faculties |
| `instructors` | Teaching staff per department |
| `courses` | Courses offered by departments |
| `rooms` | Classrooms and lecture halls |
| `semesters` | Academic semesters |
| `schedules` | Course + instructor + semester + room combinations |
| `students` | Enrolled students |
| `enrollments` | M:N bridge — students enrolled in schedules |
| `grades` | Scores and letter grades per enrollment |

## Design Decisions

- **`enrollments`** is the M:N bridge between `students` and `schedules`.
  A student can attend many schedules; a schedule can have many students.

- **`letter_grade`** in `grades` is a `GENERATED ALWAYS AS` column —
  automatically computed from `score`. It is never inserted directly.

- **ON DELETE RESTRICT** is used on most FK relationships to prevent
  accidental deletion of parent records that have children.

- **ON DELETE CASCADE** is used on `enrollments` and `grades` —
  if a student is deleted, their enrollments and grades are removed too.

- All dates in INSERT statements are after `2026-01-01` to satisfy
  the CHECK constraints on `hire_date`, `enrolled_at`, and `start_date`.

## Roles

| Role | Permissions |
|------|-------------|
| `university_readonly` | SELECT on all tables (for reporting) |
| `university_writer` | INSERT, UPDATE on enrollments (student portal) |
