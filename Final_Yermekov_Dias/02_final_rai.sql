CREATE SCHEMA IF NOT EXISTS university;

-- ============================================================
-- PART 2: CREATE TABLE
-- ============================================================

-- Parent tables first (no FK dependencies)

CREATE TABLE IF NOT EXISTS university.faculties (
    faculty_id        SERIAL PRIMARY KEY,
    faculty_name      VARCHAR(150) NOT NULL UNIQUE,
    -- Business rule: university was founded after 1900
    established_year  INT CHECK (established_year > 1900),
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS university.rooms (
    room_id      SERIAL PRIMARY KEY,
    room_number  VARCHAR(20) NOT NULL UNIQUE,
    -- Business rule: capacity cannot be negative
    capacity     INT NOT NULL CHECK (capacity >= 0),
    building     VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS university.semesters (
    semester_id    SERIAL PRIMARY KEY,
    semester_name  VARCHAR(30) NOT NULL UNIQUE,
    -- Business rule: semester must start after system launch date
    start_date     DATE NOT NULL CHECK (start_date > DATE '2026-01-01'),
    end_date       DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS university.students (
    student_id   SERIAL PRIMARY KEY,
    full_name    VARCHAR(150) NOT NULL,
    -- Business rule: email must be unique across all students
    email        VARCHAR(120) NOT NULL UNIQUE,
    birth_date   DATE,
    -- Business rule: gender limited to defined values
    gender       VARCHAR(10) NOT NULL CHECK (gender IN ('M', 'F', 'Other')),
    -- Business rule: enrollment date must be after system launch
    enrolled_at  DATE NOT NULL CHECK (enrolled_at > DATE '2026-01-01')
);

-- Child tables (depend on parents above)

CREATE TABLE IF NOT EXISTS university.departments (
    department_id    SERIAL PRIMARY KEY,
    faculty_id       INT NOT NULL REFERENCES university.faculties(faculty_id) ON DELETE RESTRICT,
    -- Business rule: department name must be unique
    department_name  VARCHAR(150) NOT NULL UNIQUE,
    office_room      VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS university.instructors (
    instructor_id  SERIAL PRIMARY KEY,
    department_id  INT NOT NULL REFERENCES university.departments(department_id) ON DELETE RESTRICT,
    full_name      VARCHAR(150) NOT NULL,
    -- Business rule: instructor email must be unique
    email          VARCHAR(120) NOT NULL UNIQUE,
    -- Business rule: hire date must be after system launch
    hire_date      DATE NOT NULL CHECK (hire_date > DATE '2026-01-01'),
    -- Business rule: rank limited to defined academic titles
    rank           VARCHAR(30) NOT NULL CHECK (rank IN ('lecturer', 'professor', 'assistant'))
);

CREATE TABLE IF NOT EXISTS university.courses (
    course_id    SERIAL PRIMARY KEY,
    department_id INT NOT NULL REFERENCES university.departments(department_id) ON DELETE RESTRICT,
    -- Business rule: course code must be unique
    course_code  VARCHAR(20) NOT NULL UNIQUE,
    course_name  VARCHAR(200) NOT NULL,
    -- Business rule: credits must be at least 1
    credits      INT NOT NULL CHECK (credits >= 1)
);

CREATE TABLE IF NOT EXISTS university.schedules (
    schedule_id    SERIAL PRIMARY KEY,
    course_id      INT NOT NULL REFERENCES university.courses(course_id) ON DELETE RESTRICT,
    instructor_id  INT NOT NULL REFERENCES university.instructors(instructor_id) ON DELETE RESTRICT,
    semester_id    INT NOT NULL REFERENCES university.semesters(semester_id) ON DELETE RESTRICT,
    room_id        INT NOT NULL REFERENCES university.rooms(room_id) ON DELETE RESTRICT,
    -- Business rule: classes only on weekdays
    day_of_week    VARCHAR(10) NOT NULL CHECK (day_of_week IN ('Mon', 'Tue', 'Wed', 'Thu', 'Fri')),
    start_time     TIME NOT NULL
);

-- M:N bridge table: students <-> schedules
CREATE TABLE IF NOT EXISTS university.enrollments (
    enrollment_id  SERIAL PRIMARY KEY,
    student_id     INT NOT NULL REFERENCES university.students(student_id) ON DELETE CASCADE,
    schedule_id    INT NOT NULL REFERENCES university.schedules(schedule_id) ON DELETE CASCADE,
    enrolled_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    status         VARCHAR(20) NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS university.grades (
    grade_id       SERIAL PRIMARY KEY,
    enrollment_id  INT NOT NULL REFERENCES university.enrollments(enrollment_id) ON DELETE CASCADE,
    -- Business rule: score cannot be negative
    score          NUMERIC(5,2) CHECK (score >= 0),
    -- GENERATED column: letter grade derived from score
    letter_grade   VARCHAR(2) GENERATED ALWAYS AS (
        CASE
            WHEN score >= 90 THEN 'A'
            WHEN score >= 80 THEN 'B'
            WHEN score >= 70 THEN 'C'
            WHEN score >= 60 THEN 'D'
            ELSE 'F'
        END
    ) STORED,
    graded_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- PART 3: ALTER TABLE — schema evolution
-- ============================================================

-- 1. Phone number column added: instructors need contact info
ALTER TABLE university.instructors
    ADD COLUMN IF NOT EXISTS phone_number VARCHAR(15);

-- 2. Expand phone field: international numbers can be longer
ALTER TABLE university.instructors
    ALTER COLUMN phone_number TYPE VARCHAR(20);

-- 3. Rename ambiguous column: 'status' → 'enrollment_status' for clarity
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns
        WHERE table_schema = 'university'
        AND table_name = 'enrollments'
        AND column_name = 'status'
    ) THEN
        ALTER TABLE university.enrollments RENAME COLUMN status TO enrollment_status;
    END IF;
END $$;

-- 4. Add default for new orders: new enrollments are always 'active'
ALTER TABLE university.enrollments
    ALTER COLUMN enrollment_status SET DEFAULT 'active';

-- 5. Add max capacity constraint to courses: no more than 500 credits total
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_constraint
        WHERE conname = 'chk_credits_max'
        AND conrelid = 'university.courses'::regclass
    ) THEN
        ALTER TABLE university.courses
            ADD CONSTRAINT chk_credits_max CHECK (credits <= 10);
    END IF;
END $$;

-- ============================================================
-- PART 4: INSERT — re-runnable reset
-- ============================================================

-- Reset all data in correct order (children first)
TRUNCATE TABLE
    university.grades,
    university.enrollments,
    university.schedules,
    university.courses,
    university.instructors,
    university.departments,
    university.students,
    university.semesters,
    university.rooms,
    university.faculties
RESTART IDENTITY CASCADE;

-- Faculties
INSERT INTO university.faculties (faculty_name, established_year) VALUES
    ('Faculty of Computer Science', 2001),
    ('Faculty of Economics', 1998),
    ('Faculty of Mathematics', 1995);

-- Rooms
INSERT INTO university.rooms (room_number, capacity, building) VALUES
    ('A-101', 30, 'Block A'),
    ('B-205', 50, 'Block B'),
    ('C-310', 25, 'Block C');

-- Semesters
INSERT INTO university.semesters (semester_name, start_date, end_date) VALUES
    ('Spring 2026', DATE '2026-02-01', DATE '2026-05-31'),
    ('Fall 2026',   DATE '2026-09-01', DATE '2026-12-31'),
    ('Spring 2027', DATE '2027-02-01', DATE '2027-05-31');

-- Students
INSERT INTO university.students (full_name, email, birth_date, gender, enrolled_at) VALUES
    ('Raiymbek Salamat',   'raikoow@gmail.com',   DATE '2007-04-15', 'M',     DATE '2026-02-01'),
    ('Sanzhar Turlanov',  'sansan@gmail.com',       DATE '2007-07-22', 'M',     DATE '2026-02-01'),
    ('Ayat Shaymardanov',   'ayatshay@gmail.com',         DATE '2007-11-03', 'M',     DATE '2026-02-01'),
    ('Damir Gabitov','damirgabi@gmail.com',        DATE '2008-01-18', 'M',     DATE '2026-02-01'),
    ('Gizatov Temirlan',  'temirlangiza@gmail.com',     DATE '2007-09-10', 'M',     DATE '2026-02-01');

-- Departments
INSERT INTO university.departments (faculty_id, department_name, office_room) VALUES
    ((SELECT faculty_id FROM university.faculties WHERE faculty_name = 'Faculty of Computer Science'),
     'Department of Software Engineering', 'A-001'),
    ((SELECT faculty_id FROM university.faculties WHERE faculty_name = 'Faculty of Computer Science'),
     'Department of Data Science', 'A-002'),
    ((SELECT faculty_id FROM university.faculties WHERE faculty_name = 'Faculty of Economics'),
     'Department of Finance', 'B-001');

-- Instructors
INSERT INTO university.instructors (department_id, full_name, email, hire_date, rank) VALUES
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Software Engineering'),
     'Ermekov Dias', 'diasermekov@gmail.com', DATE '2026-02-01', 'professor'),
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Data Science'),
     'Daulbai Anuarbek',     'daulbaianuar@gmail.com',   DATE '2026-02-01', 'lecturer'),
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Finance'),
     'Aibaruly Gaziz', 'a.gaziz@gmail.com',    DATE '2026-02-01', 'assistant');

-- Courses
INSERT INTO university.courses (department_id, course_code, course_name, credits) VALUES
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Software Engineering'),
     'SE-101', 'Introduction to Programming', 5),
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Data Science'),
     'DS-201', 'Database Systems', 4),
    ((SELECT department_id FROM university.departments WHERE department_name = 'Department of Finance'),
     'FN-301', 'Financial Accounting', 3);

-- Schedules
INSERT INTO university.schedules (course_id, instructor_id, semester_id, room_id, day_of_week, start_time) VALUES
    (
        (SELECT course_id FROM university.courses WHERE course_code = 'SE-101'),
        (SELECT instructor_id FROM university.instructors WHERE email = 'diasermekov@gmail.com'),
        (SELECT semester_id FROM university.semesters WHERE semester_name = 'Spring 2026'),
        (SELECT room_id FROM university.rooms WHERE room_number = 'A-101'),
        'Mon', '09:00'
    ),
    (
        (SELECT course_id FROM university.courses WHERE course_code = 'DS-201'),
        (SELECT instructor_id FROM university.instructors WHERE email = 'daulbaianuar@gmail.com'),
        (SELECT semester_id FROM university.semesters WHERE semester_name = 'Spring 2026'),
        (SELECT room_id FROM university.rooms WHERE room_number = 'B-205'),
        'Wed', '11:00'
    ),
    (
        (SELECT course_id FROM university.courses WHERE course_code = 'FN-301'),
        (SELECT instructor_id FROM university.instructors WHERE email = 'a.gaziz@gmail.com'),
        (SELECT semester_id FROM university.semesters WHERE semester_name = 'Spring 2026'),
        (SELECT room_id FROM university.rooms WHERE room_number = 'C-310'),
        'Fri', '14:00'
    );

-- Enrollments (M:N bridge) — using INSERT ... SELECT
INSERT INTO university.enrollments (student_id, schedule_id, enrolled_date)
SELECT s.student_id, sc.schedule_id, DATE '2026-02-05'
FROM (VALUES
    ('raikoow@gmail.com',  'SE-101'),
    ('raikoow@gmail.com',  'DS-201'),
    ('sansan@gmail.com',     'DS-201'),
    ('sansan@gmail.com',     'FN-301'),
    ('ayatshay@gmail.com',       'SE-101'),
    ('damirgabi@gmail.com',      'FN-301'),
    ('temirlangiza@gmail.com',   'SE-101')
) AS x(email, code)
JOIN university.students  s  ON s.email = x.email
JOIN university.courses   c  ON c.course_code = x.code
JOIN university.schedules sc ON sc.course_id = c.course_id;

-- Grades
INSERT INTO university.grades (enrollment_id, score) VALUES
    ((SELECT e.enrollment_id FROM university.enrollments e
      JOIN university.students s ON s.student_id = e.student_id
      JOIN university.schedules sc ON sc.schedule_id = e.schedule_id
      JOIN university.courses c ON c.course_id = sc.course_id
      WHERE s.email = 'raikoow@gmail.com' AND c.course_code = 'SE-101'), 92.50),
    ((SELECT e.enrollment_id FROM university.enrollments e
      JOIN university.students s ON s.student_id = e.student_id
      JOIN university.schedules sc ON sc.schedule_id = e.schedule_id
      JOIN university.courses c ON c.course_id = sc.course_id
      WHERE s.email = 'sansan@gmail.com' AND c.course_code = 'DS-201'), 78.00),
    ((SELECT e.enrollment_id FROM university.enrollments e
      JOIN university.students s ON s.student_id = e.student_id
      JOIN university.schedules sc ON sc.schedule_id = e.schedule_id
      JOIN university.courses c ON c.course_id = sc.course_id
      WHERE s.email = 'ayatshay@gmail.com' AND c.course_code = 'SE-101'), 85.00);

-- ============================================================
-- PART 5: UPDATE
-- ============================================================

-- Simple UPDATE: mark high-performing students as 'honours'
-- Business reason: students with score >= 90 receive honours status
ALTER TABLE university.students
    ADD COLUMN IF NOT EXISTS standing VARCHAR(20) NOT NULL DEFAULT 'regular';

UPDATE university.students
SET standing = 'honours'
WHERE student_id IN (
    SELECT s.student_id
    FROM university.students s
    JOIN university.enrollments e ON e.student_id = s.student_id
    JOIN university.grades g ON g.enrollment_id = e.enrollment_id
    WHERE g.score >= 90
);

-- UPDATE ... FROM: sync instructor rank based on number of courses taught
-- Business reason: instructors teaching 2+ courses are promoted to 'professor'
UPDATE university.instructors i
SET rank = 'professor'
FROM (
    SELECT sc.instructor_id, COUNT(*) AS course_count
    FROM university.schedules sc
    GROUP BY sc.instructor_id
) sub
WHERE i.instructor_id = sub.instructor_id
  AND sub.course_count >= 2
  AND i.rank != 'professor';

-- ============================================================
-- PART 5: DELETE
-- ============================================================

-- Business reason: remove enrollments with 'dropped' status older than 90 days.
-- Wrapped in BEGIN...ROLLBACK so demo data survives for the defense.
BEGIN;
    DELETE FROM university.enrollments
    WHERE enrollment_status = 'dropped'
      AND enrolled_date < CURRENT_DATE - INTERVAL '90 days'
    RETURNING enrollment_id, student_id, enrolled_date;
ROLLBACK;

-- ============================================================
-- PART 6: GRANT / REVOKE
-- ============================================================

-- Re-runnable role cleanup
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'university_readonly') THEN
        REASSIGN OWNED BY university_readonly TO CURRENT_USER;
        DROP OWNED BY university_readonly;
        DROP ROLE university_readonly;
    END IF;
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'university_writer') THEN
        REASSIGN OWNED BY university_writer TO CURRENT_USER;
        DROP OWNED BY university_writer;
        DROP ROLE university_writer;
    END IF;
END $$;

-- Two roles for the application
CREATE ROLE university_readonly;
CREATE ROLE university_writer;

-- Schema access required before table-level grants
GRANT USAGE ON SCHEMA university TO university_readonly, university_writer;

-- Reader role: can only SELECT (for reporting and analytics)
GRANT SELECT ON ALL TABLES IN SCHEMA university TO university_readonly;

-- Writer role: can manage enrollments and grades (student portal)
GRANT INSERT, UPDATE ON university.enrollments TO university_writer;
GRANT INSERT, UPDATE ON university.grades TO university_writer;

-- REVOKE: after review, writers must not DELETE grades directly;
-- deletions go through a separate admin-logged process.
REVOKE UPDATE ON university.grades FROM university_writer;










--SELECT * FROM university.students;
--SELECT * FROM university.enrollments;
--SELECT * FROM university.grades;
