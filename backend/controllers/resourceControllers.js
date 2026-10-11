import ActivityLog from '../models/ActivityLog.js';
import Announcement from '../models/Announcement.js';
import Enrollment from '../models/Enrollment.js';
import Grade from '../models/Grade.js';
import Notification from '../models/Notification.js';
import Schedule from '../models/Schedule.js';
import { getSettings } from '../models/Setting.js';
import Student from '../models/Student.js';
import Subject from '../models/Subject.js';
import Ticket from '../models/Ticket.js';
import User from '../models/User.js';
import { HttpError } from '../middleware/error.js';
import { crudController } from '../utils/crud.js';
import {
  assertAnnouncementTarget,
  assertEnrollmentTransition,
  assertScheduleValid,
  assertSectionMatches,
  canPublishGrade,
  initials,
} from '../utils/rules.js';

export const DEFAULT_SECTIONS = [
  'BSIT 1A', 'BSIT 2A', 'BSIT 3A', 'BSIT 3B', 'BSIT 4A',
  'BSBA 2A', 'BSBA 3A', 'BSEd 1A', 'BSEd 2A', 'BSEd 4A',
];

export const knownSections = async () =>
  [...new Set([...DEFAULT_SECTIONS, ...(await Student.distinct('section'))])].sort();

// ─── Students ────────────────────────────────────────────────────────
export const students = crudController(Student, {
  searchFields: ['fullName', 'studentId', 'email', 'section'],
  filterFields: ['program', 'yearLevel', 'section', 'academicStatus'],
  beforeSave: async ({ doc }) => {
    assertSectionMatches(doc);
    doc.avatarInitials = initials(doc.fullName);
    if (doc.user && doc.isModified('email')) {
      const taken = await User.exists({ email: doc.email, _id: { $ne: doc.user } });
      if (taken) throw new HttpError(409, 'Another account already uses this email.');
    }
  },
  afterSave: async ({ doc, previous }) => {
    // Keep the login account in step with the student record.
    if (doc.user) {
      await User.updateOne(
        { _id: doc.user },
        { email: doc.email, name: doc.fullName, studentId: doc.studentId }
      );
    }
    // Records store a copy of the student's name/number for display; keep them in sync.
    if (previous) {
      const linked = {
        studentName: doc.fullName,
        studentNumber: doc.studentId,
        program: doc.program,
        section: doc.section,
      };
      await Promise.all([
        Enrollment.updateMany({ studentId: doc.id }, { ...linked, yearLevel: doc.yearLevel }),
        Grade.updateMany({ studentId: doc.id }, linked),
        Ticket.updateMany(
          { studentNumber: previous.studentId },
          { studentName: doc.fullName, studentNumber: doc.studentId }
        ),
      ]);
    }
  },
  beforeDelete: async ({ doc }) => {
    const [enrollments, grades, tickets] = await Promise.all([
      Enrollment.exists({ studentId: doc.id }),
      Grade.exists({ studentId: doc.id }),
      Ticket.exists({ studentNumber: doc.studentId }),
    ]);
    if (enrollments || grades || tickets) {
      throw new HttpError(
        409,
        'This student has enrollment, grade, or support history. Keep the record and update their status instead.'
      );
    }
  },
  afterDelete: async ({ doc }) => {
    if (doc.user) await User.deleteOne({ _id: doc.user, role: 'student' });
  },
});

// ─── Enrollments ─────────────────────────────────────────────────────
export const enrollments = crudController(Enrollment, {
  searchFields: ['studentName', 'studentNumber', 'section'],
  filterFields: ['status', 'program', 'yearLevel', 'section', 'studentId'],
  beforeSave: async ({ doc, previous }) => {
    if (!previous && !(await getSettings()).enrollmentOpen) {
      throw new HttpError(409, 'Enrollment submissions are closed.');
    }
    if (!(await Student.exists({ _id: doc.studentId }))) {
      throw new HttpError(400, 'Enrollment must belong to an existing student.');
    }
    assertEnrollmentTransition(previous, doc);
    if (doc.status === 'Rejected') doc.remarks = doc.remarks.trim();
  },
});

// ─── Grades ──────────────────────────────────────────────────────────
// Student name/section copies may change while encoding is closed; grades may not.
const GRADE_FIELDS = ['subjectCode', 'subjectTitle', 'midtermGrade', 'finalGrade', 'units', 'publishStatus', 'semester', 'academicYear'];
export const grades = crudController(Grade, {
  searchFields: ['studentName', 'studentNumber', 'subjectCode', 'subjectTitle'],
  filterFields: ['studentId', 'section', 'program', 'publishStatus', 'semester', 'academicYear'],
  beforeSave: async ({ doc, previous }) => {
    const gradeChanged = !previous || GRADE_FIELDS.some((field) => doc.isModified(field));
    if (gradeChanged && !(await getSettings()).gradeEncodingOpen) {
      throw new HttpError(409, 'Grade encoding is disabled in Settings.');
    }
    if (!(await Student.exists({ _id: doc.studentId }))) {
      throw new HttpError(400, 'Grade must belong to an existing student.');
    }
    if (doc.publishStatus === 'Published' && !canPublishGrade(doc)) {
      throw new HttpError(400, 'Only valid, complete final grades can be published.');
    }
  },
});

// ─── Schedules ───────────────────────────────────────────────────────
export const schedules = crudController(Schedule, {
  searchFields: ['subjectCode', 'subjectTitle', 'instructor', 'room', 'section'],
  filterFields: ['section', 'program', 'day', 'instructor'],
  beforeSave: async ({ doc }) => {
    const sameDay = await Schedule.find({ day: doc.day, _id: { $ne: doc.id } });
    assertScheduleValid(doc, sameDay);
  },
});

// ─── Announcements ───────────────────────────────────────────────────
export const announcements = crudController(Announcement, {
  searchFields: ['title', 'message'],
  filterFields: ['status', 'category', 'targetAudience'],
  beforeSave: async ({ doc }) => {
    assertAnnouncementTarget(doc, await knownSections());
  },
});

// ─── Support tickets ─────────────────────────────────────────────────
export const tickets = crudController(Ticket, {
  searchFields: ['ticketNumber', 'studentName', 'studentNumber', 'subject'],
  filterFields: ['status', 'category', 'studentNumber'],
});

// ─── Admin notifications, activity log, subject catalog ──────────────
export const notifications = crudController(Notification, { filterFields: ['type'] });
export const activityLogs = crudController(ActivityLog, { filterFields: ['type'] });
export const subjects = crudController(Subject, {
  searchFields: ['code', 'title'],
  beforeDelete: async ({ doc }) => {
    if (await Enrollment.exists({ 'subjects.code': doc.code })) {
      throw new HttpError(409, 'Subject is used by enrollments and cannot be deleted.');
    }
  },
});
