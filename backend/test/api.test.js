// API integration tests. Needs a running MongoDB; uses a separate `edutrack_test`
// database built from MONGO_URI, so development data is never touched.
// Run with: npm test
import assert from 'node:assert/strict';
import { after, before, describe, it, mock } from 'node:test';
import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config({ quiet: true });
const testUri = new URL(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/edutrack');
testUri.pathname = '/edutrack_test';
process.env.MONGO_URI = testUri.toString();
process.env.JWT_SECRET ||= 'test-secret-that-is-long-enough-for-hs256-signing';
process.env.EMAIL_USER = ''; // never send real email from tests
process.env.EMAIL_PASS = '';
process.env.AUTH_RATE_LIMIT = '1000';

const { default: app } = await import('../app.js');
const { seedDatabase } = await import('../config/seed.js');

let server;
let base;
const call = async (method, path, { token, body } = {}) => {
  const res = await fetch(`${base}/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
};
const login = async (identifier, password, role) =>
  (await call('POST', '/auth/login', { body: { identifier, password, role } })).body.token;

let admin;
let student;

before(async () => {
  await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 5000 });
  await seedDatabase({ log: () => {} });
  server = app.listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
  admin = await login('admin@edutrack.edu', 'Admin123!', 'admin');
  student = await login('juan.delacruz@edutrack.edu', 'Student123!', 'student');
});

after(async () => {
  server?.close();
  await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
});

describe('authentication & security', () => {
  it('signs in admins and students with JWTs', () => {
    assert.ok(admin);
    assert.ok(student);
  });

  it('rejects wrong passwords without revealing whether the account exists', async () => {
    const wrong = await call('POST', '/auth/login', { body: { identifier: 'admin@edutrack.edu', password: 'nope' } });
    const unknown = await call('POST', '/auth/login', { body: { identifier: 'ghost@edutrack.edu', password: 'nope' } });
    assert.equal(wrong.status, 401);
    assert.equal(unknown.status, 401);
    assert.equal(wrong.body.message, unknown.body.message);
  });

  it('accepts a student ID as the login identifier', async () => {
    assert.ok(await login('2024-00115', 'Student123!', 'student'));
  });

  it('blocks a NoSQL-injection login attempt', async () => {
    const res = await call('POST', '/auth/login', {
      body: { identifier: { $ne: null }, password: { $ne: null } },
    });
    assert.equal(res.status, 400);
  });

  it('protects routes: no token -> 401, student on admin route -> 403', async () => {
    assert.equal((await call('GET', '/students')).status, 401);
    assert.equal((await call('GET', '/students', { token: 'not-a-jwt' })).status, 401);
    assert.equal((await call('GET', '/students', { token: student })).status, 403);
    assert.equal((await call('GET', '/portal/profile', { token: admin })).status, 403);
  });

  it('returns the signed-in user without the password hash', async () => {
    const res = await call('GET', '/auth/me', { token: student });
    assert.equal(res.status, 200);
    assert.equal(res.body.user.role, 'student');
    assert.equal(res.body.user.profile.studentId, '2024-00115');
    assert.equal(res.body.user.password, undefined);
  });

  it('requires email verification and never lets registration create admins', async () => {
    const email = 'new.student@example.com';
    const form = { email, firstName: 'Nina', lastName: 'Garcia', password: 'Passw0rd!', program: 'BS Information Technology', yearLevel: '1st Year' };
    assert.equal((await call('POST', '/auth/register', { body: form })).status, 400);

    const logs = mock.method(console, 'log', () => {});
    await call('POST', '/auth/send-otp', { body: { email } });
    const code = logs.mock.calls.map((c) => String(c.arguments[0])).join('\n').match(/OTP: (\d{5})/)?.[1];
    logs.mock.restore();
    assert.ok(code, 'development OTP is logged when email is not configured');

    assert.equal((await call('POST', '/auth/verify-otp', { body: { email, otp: '00000' } })).status, 400);
    assert.equal((await call('POST', '/auth/verify-otp', { body: { email, otp: code } })).status, 200);
    const res = await call('POST', '/auth/register', { body: { ...form, role: 'admin' } });
    assert.equal(res.status, 201);
    assert.equal(res.body.user.role, 'student');
    assert.equal(res.body.user.profile.section, 'BSIT 1A');
    // The new student immediately appears in the admin directory.
    const list = await call('GET', `/students?search=${encodeURIComponent(email)}`, { token: admin });
    assert.equal(list.body.total, 1);
  });

  it('lets students edit only their contact details', async () => {
    const contact = {
      contactNumber: '+63 917 000 1234',
      address: '456 Rizal Ave, Manila',
      personalEmail: 'juan.personal@example.com',
      emergencyContact: 'Maria Dela Cruz',
      emergencyContactNumber: '0918 222 3333',
      guardianRelationship: 'Mother',
    };
    const res = await call('PUT', '/portal/profile', {
      token: student,
      body: { ...contact, role: 'admin', studentId: '9999-99999', fullName: 'Changed', program: 'BSBA', email: 'x@example.com' },
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.contactNumber, contact.contactNumber);
    assert.equal(res.body.studentId, '2024-00115');
    assert.equal(res.body.fullName, 'Juan Manuel Dela Cruz');
    assert.equal(res.body.program, 'BSIT');
    assert.equal(res.body.email, 'juan.delacruz@edutrack.edu');
    assert.equal((await call('GET', '/auth/me', { token: student })).body.user.role, 'student');
    const invalid = await call('PUT', '/portal/profile', { token: student, body: { ...contact, contactNumber: 'abc', personalEmail: 'nope' } });
    assert.equal(invalid.status, 400);
    assert.match(invalid.body.message, /contactNumber/);
  });

  it('changes a password with the current one', async () => {
    const token = await login('pedro.santos@university.edu', 'Student123!');
    const bad = await call('PUT', '/auth/password', { token, body: { currentPassword: 'wrong', password: 'NewPass123' } });
    assert.equal(bad.status, 400);
    const ok = await call('PUT', '/auth/password', { token, body: { currentPassword: 'Student123!', password: 'NewPass123' } });
    assert.equal(ok.status, 200);
    assert.ok(await login('pedro.santos@university.edu', 'NewPass123'));
  });
});

describe('admin CRUD (students)', () => {
  const record = {
    id: 'test-student',
    studentId: '2026-99999',
    fullName: 'Test Student',
    email: 'test.student@university.edu',
    contactNumber: '0917 000 0000',
    address: 'Manila',
    emergencyContact: 'Parent',
    emergencyContactNumber: '0917 111 1111',
    program: 'BSIT',
    yearLevel: '2nd Year',
    section: 'BSIT 2A',
    academicStatus: 'Active',
    dateEnrolled: '2026-06-01',
  };

  it('creates, reads, updates and deletes a record', async () => {
    const created = await call('POST', '/students', { token: admin, body: record });
    assert.equal(created.status, 201);
    assert.equal(created.body.id, 'test-student');
    assert.equal(created.body.avatarInitials, 'TS');

    assert.equal((await call('GET', '/students/test-student', { token: admin })).body.fullName, 'Test Student');

    const updated = await call('PUT', '/students/test-student', { token: admin, body: { ...record, fullName: 'Updated Name' } });
    assert.equal(updated.body.fullName, 'Updated Name');

    assert.equal((await call('DELETE', '/students/test-student', { token: admin })).status, 200);
    assert.equal((await call('GET', '/students/test-student', { token: admin })).status, 404);
  });

  it('validates input and enforces unique student IDs', async () => {
    const invalid = await call('POST', '/students', { token: admin, body: { ...record, email: 'not-an-email', program: 'BSXX' } });
    assert.equal(invalid.status, 400);
    assert.match(invalid.body.message, /email/);
    const duplicate = await call('POST', '/students', { token: admin, body: { ...record, id: 'dup', studentId: '2024-00103' } });
    assert.equal(duplicate.status, 409);
    const mismatch = await call('POST', '/students', { token: admin, body: { ...record, id: 'mm', section: 'BSBA 2A' } });
    assert.equal(mismatch.status, 400);
  });

  it('searches, filters and paginates', async () => {
    const page = await call('GET', '/students?program=BSIT&limit=2&page=2', { token: admin });
    assert.equal(page.body.items.length, 2);
    assert.equal(page.body.page, 2);
    assert.ok(page.body.items.every((s) => s.program === 'BSIT'));
    const search = await call('GET', '/students?search=dela%20cruz', { token: admin });
    assert.equal(search.body.items[0].studentId, '2024-00115');
  });

  it('refuses to delete students with academic history', async () => {
    const res = await call('DELETE', '/students/st1', { token: admin });
    assert.equal(res.status, 409);
  });
});

describe('student portal <-> admin portal', () => {
  let enrollmentId;

  it('student submits an enrollment that the admin can review', async () => {
    // CS201 was already passed (published grade with remark "Passed").
    const catalog = await call('GET', '/portal/subjects', { token: student });
    assert.equal(catalog.body.find((s) => s.code === 'CS201').passed, true);
    const repeat = await call('POST', '/portal/enrollment', { token: student, body: { subjectCodes: ['CS201', 'CS203'] } });
    assert.equal(repeat.status, 400);
    assert.match(repeat.body.message, /already passed: CS201/);

    const submitted = await call('POST', '/portal/enrollment', {
      token: student,
      body: { subjectCodes: ['CS203', 'CS204', 'CS206'] },
    });
    assert.equal(submitted.status, 201);
    assert.equal(submitted.body.status, 'Pending');
    // CS204/CS206 prerequisites (CS201/CS202) were passed by the demo student.
    assert.equal(submitted.body.hasPrerequisiteConcerns, false);
    enrollmentId = submitted.body.id;

    const boot = await call('GET', '/admin/bootstrap', { token: admin });
    assert.ok(boot.body.state.enrollments.some((e) => e.id === enrollmentId));
    assert.ok(boot.body.state.notifications.some((n) => n.href === `/enrollment?record=${enrollmentId}`));
  });

  it('admin approval is visible to the student; reviewed requests cannot be re-reviewed', async () => {
    const { body: enrollment } = await call('GET', `/enrollments/${enrollmentId}`, { token: admin });
    const rejectWithoutRemarks = await call('PUT', `/enrollments/${enrollmentId}`, {
      token: admin,
      body: { ...enrollment, status: 'Rejected', remarks: '' },
    });
    assert.equal(rejectWithoutRemarks.status, 400);
    const approved = await call('PUT', `/enrollments/${enrollmentId}`, { token: admin, body: { ...enrollment, status: 'Approved' } });
    assert.equal(approved.status, 200);
    const again = await call('PUT', `/enrollments/${enrollmentId}`, {
      token: admin,
      body: { ...enrollment, status: 'Rejected', remarks: 'Too late' },
    });
    assert.equal(again.status, 409);

    const mine = await call('GET', '/portal/enrollment', { token: student });
    assert.equal(mine.body.enrollment.status, 'Approved');
  });

  it('only published grades reach the student', async () => {
    const grade = {
      id: 'g-test',
      studentId: 'st13',
      studentName: 'Juan Manuel Dela Cruz',
      studentNumber: '2024-00115',
      subjectCode: 'CS203',
      subjectTitle: 'Web Systems',
      section: 'BSIT 3A',
      program: 'BSIT',
      midtermGrade: 1.5,
      finalGrade: 3.5,
      units: 3,
      publishStatus: 'Draft',
      semester: '1st Semester',
      academicYear: '2024-2025',
    };
    const draft = await call('POST', '/grades', { token: admin, body: grade });
    assert.equal(draft.body.remark, 'Failed');
    let mine = await call('GET', '/portal/grades', { token: student });
    assert.ok(!mine.body.some((g) => g.id === 'g-test'));
    await call('PUT', '/grades/g-test', { token: admin, body: { ...grade, publishStatus: 'Published' } });
    mine = await call('GET', '/portal/grades', { token: student });
    assert.ok(mine.body.some((g) => g.id === 'g-test'));
  });

  it('rejects conflicting class schedules', async () => {
    const { body } = await call('GET', '/schedules?limit=1', { token: admin });
    const existing = body.items[0];
    const clash = await call('POST', '/schedules', { token: admin, body: { ...existing, id: 'clash' } });
    assert.equal(clash.status, 409);
    assert.match(clash.body.message, /conflict/i);
  });

  it('tickets flow from student to admin helpdesk and back', async () => {
    const created = await call('POST', '/portal/tickets', {
      token: student,
      body: { category: 'Grades', subject: 'Grade question', message: 'Could you check my CS203 grade?' },
    });
    assert.equal(created.status, 201);
    const ticket = created.body;
    const reply = { id: 'r1', author: 'Registrar', message: 'Checking now.', timestamp: new Date().toISOString(), isAdmin: true };
    const answered = await call('PUT', `/tickets/${ticket.id}`, {
      token: admin,
      body: { ...ticket, status: 'In Progress', replies: [reply] },
    });
    assert.equal(answered.status, 200);
    const mine = await call('GET', '/portal/tickets', { token: student });
    assert.equal(mine.body[0].replies[0].message, 'Checking now.');
  });

  it('closing enrollment in settings blocks student submissions', async () => {
    const { body: settings } = await call('GET', '/settings', { token: student });
    assert.equal((await call('PUT', '/settings', { token: student, body: settings })).status, 403);
    await call('PUT', '/settings', { token: admin, body: { ...settings, enrollmentOpen: false } });
    const blocked = await call('POST', '/portal/enrollment', { token: student, body: { subjectCodes: ['GE101'] } });
    assert.equal(blocked.status, 409);
  });
});
