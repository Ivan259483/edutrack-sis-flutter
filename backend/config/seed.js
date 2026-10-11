// Shared demo dataset used by both portals (see seeder.js and the API tests).
import { readFileSync } from 'node:fs';
import ActivityLog from '../models/ActivityLog.js';
import Announcement from '../models/Announcement.js';
import Enrollment from '../models/Enrollment.js';
import Grade from '../models/Grade.js';
import Notification from '../models/Notification.js';
import Otp from '../models/Otp.js';
import Schedule from '../models/Schedule.js';
import Setting from '../models/Setting.js';
import Student from '../models/Student.js';
import Subject from '../models/Subject.js';
import Ticket from '../models/Ticket.js';
import User from '../models/User.js';

const data = JSON.parse(readFileSync(new URL('../seed/data.json', import.meta.url), 'utf8'));

// Demo-only passwords for local testing.
// SEED_ADMIN_PASSWORD overrides the admin password (use a strong one for any
// online database); the default is only for local demos.
const ADMIN = {
  name: 'Dr. Maria Santos',
  email: 'admin@edutrack.edu',
  password: process.env.SEED_ADMIN_PASSWORD || 'Admin123!',
};
const STUDENT_PASSWORD = 'Student123!';

// The EduTrack portal's demo student, added to the shared dataset.
const demoStudent = {
  id: 'st13',
  studentId: '2024-00115',
  fullName: 'Juan Manuel Dela Cruz',
  email: 'juan.delacruz@edutrack.edu',
  contactNumber: '+63 912 345 6789',
  address: '123 Mabini St., Sampaloc, Manila',
  emergencyContact: 'Maria Dela Cruz',
  emergencyContactNumber: '+63 917 654 3210',
  program: 'BSIT',
  yearLevel: '3rd Year',
  section: 'BSIT 3A',
  academicStatus: 'Active',
  dateEnrolled: '2022-06-15',
  avatarInitials: 'JM',
  gender: 'Male',
  dateOfBirth: '2003-05-14',
  civilStatus: 'Single',
  nationality: 'Filipino',
  personalEmail: 'juan.delacruz@gmail.com',
  guardianRelationship: 'Mother',
};
const demoGrades = [
  ['g-jdc-1', 'CS201', 'Data Structures', 1.5, 1.75],
  ['g-jdc-2', 'CS202', 'Information Management', 1.75, 1.5],
  ['g-jdc-3', 'GE101', 'English Communication', 1.25, 1.25],
].map(([id, subjectCode, subjectTitle, midtermGrade, finalGrade]) => ({
  id,
  studentId: demoStudent.id,
  studentName: demoStudent.fullName,
  studentNumber: demoStudent.studentId,
  subjectCode,
  subjectTitle,
  section: demoStudent.section,
  program: demoStudent.program,
  midtermGrade,
  finalGrade,
  units: 3,
  publishStatus: 'Published',
  semester: '2nd Semester',
  academicYear: '2023-2024',
}));

// Mongo uses `_id`; `sortKey` preserves the dataset's newest-first order.
const base = Date.now();
const toDocs = (records) =>
  records.map(({ id, ...rest }, index) => ({ _id: id, sortKey: base - index * 1000, ...rest }));

// Link notifications to the record they describe (same rule as the admin portal seed).
const notifications = data.notifications.map((n) => {
  const isTicket = n.type === 'ticket';
  const record = isTicket
    ? data.tickets.find((t) => n.description.includes(t.studentName))
    : data.enrollments.find((e) => n.description.includes(e.studentName));
  const page = isTicket ? '/helpdesk' : '/enrollment';
  return { ...n, href: record ? `${page}?record=${encodeURIComponent(record.id)}` : page };
});

export const seedDatabase = async ({ log = console.log } = {}) => {
  await Promise.all(
    [User, Student, Subject, Enrollment, Grade, Schedule, Announcement, Ticket, Notification, ActivityLog, Setting, Otp].map(
      (Model) => Model.deleteMany({})
    )
  );
  log('🧹 Existing records cleared...');

  await User.create({ ...ADMIN, role: 'admin' });

  const students = [demoStudent, ...data.students];
  // One login account per student (create() runs the password hashing hook).
  const users = await User.create(
    students.map((s) => ({
      name: s.fullName,
      email: s.email,
      password: STUDENT_PASSWORD,
      role: 'student',
      studentId: s.studentId,
    }))
  );
  await Student.insertMany(
    toDocs(students).map((s, i) => ({ ...s, user: users[i]._id }))
  );

  await Subject.insertMany(toDocs(data.subjects));
  await Enrollment.insertMany(toDocs(data.enrollments));
  // create() (not insertMany) so remarks/numericalGrade are derived by the model.
  await Grade.create(toDocs([...demoGrades, ...data.grades]));
  await Schedule.insertMany(toDocs(data.schedules));
  await Announcement.insertMany(toDocs(data.announcements));
  await Ticket.insertMany(toDocs(data.tickets));
  await Notification.insertMany(toDocs(notifications));
  await ActivityLog.insertMany(toDocs(data.activityLogs));
  await Setting.create({ _id: 'system', ...data.settings });

  log(`✅ Seeded ${students.length} students, ${data.subjects.length} subjects, ${data.enrollments.length} enrollments,`);
  log(`   ${data.grades.length + demoGrades.length} grades, ${data.schedules.length} schedules, ${data.tickets.length} tickets.`);
  log(
    process.env.SEED_ADMIN_PASSWORD
      ? '   🛡️  Admin:   admin@edutrack.edu | (password from SEED_ADMIN_PASSWORD)'
      : '   🛡️  Admin:   admin@edutrack.edu | Admin123!'
  );
  log('   🎓  Student: juan.delacruz@edutrack.edu (or 2024-00115) | Student123!');
  log(`   🎓  Every other sample student signs in with their email and ${STUDENT_PASSWORD}`);
};
