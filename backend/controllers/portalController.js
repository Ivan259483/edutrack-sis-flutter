// Student portal endpoints. Every query is scoped to the signed-in student's
// own record, so students can never read or change other students' data.
import { randomInt, randomUUID } from 'node:crypto';
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
import { asyncHandler, HttpError } from '../middleware/error.js';
import { announcementTargets, nowIso, today } from '../utils/rules.js';

const currentStudent = async (req) => {
  const student = await Student.findOne({ user: req.user._id });
  if (!student) throw new HttpError(404, 'No student record is linked to this account.');
  return student;
};

const notifyAdmins = async (settingKey, notification, action, type) => {
  const settings = await getSettings();
  const timestamp = nowIso();
  if (settings[settingKey]) await Notification.create({ ...notification, timestamp, read: false });
  await ActivityLog.create({ action, actor: 'Student Portal', timestamp, type });
};

// Subjects the student has passed: a published grade with remark "Passed"
// (the Grade model sets it when the final grade is 3.00 or better).
const passedCodes = async (student) =>
  new Set(
    (await Grade.find({ studentId: student.id, publishStatus: 'Published', finalGrade: { $lte: 3 } })).map(
      (g) => g.subjectCode
    )
  );

// @route GET /api/portal/profile
export const getProfile = asyncHandler(async (req, res) => {
  res.json(await currentStudent(req));
});

// @route PUT /api/portal/profile — update own contact details only
// (the validator whitelists the fields; identity/academic data stay registrar-managed)
export const updateProfile = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  student.set(req.body);
  await student.save();
  res.json(student);
});

// @route GET /api/portal/subjects — catalog with prerequisite status and this section's class times
export const getSubjects = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const [subjects, schedules, passed] = await Promise.all([
    Subject.find().sort({ code: 1 }),
    Schedule.find({ section: student.section }),
    passedCodes(student),
  ]);
  res.json(
    subjects.map((s) => ({
      ...s.toJSON(),
      prerequisiteMet: !s.prerequisite || passed.has(s.prerequisite),
      passed: passed.has(s.code),
      classes: schedules
        .filter((c) => c.subjectCode === s.code)
        .map(({ day, startTime, endTime, room, instructor }) => ({ day, startTime, endTime, room, instructor })),
    }))
  );
});

// @route GET /api/portal/enrollment — latest enrollment + whether submissions are open
export const getEnrollment = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const [enrollment, settings] = await Promise.all([
    Enrollment.findOne({ studentId: student.id }).sort({ sortKey: -1 }),
    getSettings(),
  ]);
  res.json({ enrollment, enrollmentOpen: settings.enrollmentOpen, period: settings });
});

// @route POST /api/portal/enrollment — submit (or revise a pending) enrollment
export const submitEnrollment = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const settings = await getSettings();
  if (!settings.enrollmentOpen) throw new HttpError(409, 'Enrollment submissions are closed.');

  const codes = [...new Set(req.body.subjectCodes.map((c) => c.toUpperCase()))];
  const [subjects, passed] = await Promise.all([Subject.find({ code: { $in: codes } }), passedCodes(student)]);
  if (subjects.length !== codes.length) throw new HttpError(400, 'One or more selected subjects do not exist.');
  const alreadyPassed = codes.filter((code) => passed.has(code));
  if (alreadyPassed.length) {
    throw new HttpError(400, `You have already passed: ${alreadyPassed.join(', ')}. Remove them from your selection.`);
  }

  const lines = subjects.map((s) => ({
    id: s.id,
    code: s.code,
    title: s.title,
    units: s.units,
    ...(s.prerequisite ? { prerequisite: s.prerequisite } : {}),
    hasPrerequisiteMet: !s.prerequisite || passed.has(s.prerequisite),
  }));
  const totalUnits = lines.reduce((sum, s) => sum + s.units, 0);
  if (totalUnits > 24) throw new HttpError(400, 'A maximum of 24 units can be enrolled.');

  const latest = await Enrollment.findOne({ studentId: student.id }).sort({ sortKey: -1 });
  if (latest?.status === 'Approved') {
    throw new HttpError(409, 'Your enrollment is already approved. Contact the registrar to make changes.');
  }

  const isRevision = latest?.status === 'Pending';
  const enrollment = isRevision ? latest : new Enrollment({ studentId: student.id });
  enrollment.set({
    studentName: student.fullName,
    studentNumber: student.studentId,
    program: student.program,
    yearLevel: student.yearLevel,
    section: student.section,
    subjects: lines,
    status: 'Pending',
    remarks: '',
    submittedDate: today(),
    hasPrerequisiteConcerns: lines.some((s) => !s.hasPrerequisiteMet),
  });
  await enrollment.save();

  await notifyAdmins(
    'notifyNewEnrollments',
    {
      title: isRevision ? 'Enrollment request revised' : 'New enrollment request',
      description: student.fullName,
      type: 'enrollment',
      href: `/enrollment?record=${encodeURIComponent(enrollment.id)}`,
    },
    `${student.fullName} ${isRevision ? 'revised' : 'submitted'} an enrollment request (${totalUnits} units)`,
    'enrollment'
  );
  res.status(isRevision ? 200 : 201).json(enrollment);
});

// @route DELETE /api/portal/enrollment — withdraw a pending request
export const cancelEnrollment = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const pending = await Enrollment.findOne({ studentId: student.id, status: 'Pending' });
  if (!pending) throw new HttpError(404, 'There is no pending enrollment to withdraw.');
  await pending.deleteOne();
  res.json({ id: pending.id, deleted: true });
});

// @route GET /api/portal/grades — published grades only
export const getGrades = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  res.json(await Grade.find({ studentId: student.id, publishStatus: 'Published' }).sort({ academicYear: -1, subjectCode: 1 }));
});

// @route GET /api/portal/schedule — classes for the student's section
export const getSchedule = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  res.json(await Schedule.find({ section: student.section }).sort({ startTime: 1 }));
});

// @route GET /api/portal/announcements — published announcements targeting this student
export const getAnnouncements = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const published = await Announcement.find({ status: 'Published' }).sort({ sortKey: -1 });
  res.json(published.filter((a) => announcementTargets(a, student)));
});

// @route GET /api/portal/tickets
export const getTickets = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  res.json(await Ticket.find({ studentNumber: student.studentId }).sort({ sortKey: -1 }));
});

// @route POST /api/portal/tickets
export const createTicket = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  let ticketNumber;
  do ticketNumber = `TKT-${new Date().getFullYear()}-${randomInt(100, 100000)}`;
  while (await Ticket.exists({ ticketNumber }));
  const ticket = await Ticket.create({
    ticketNumber,
    studentName: student.fullName,
    studentNumber: student.studentId,
    category: req.body.category,
    subject: req.body.subject,
    message: req.body.message,
    status: 'Open',
    dateCreated: today(),
    dateUpdated: today(),
    replies: [],
  });
  await notifyAdmins(
    'notifyNewTickets',
    {
      title: 'New support ticket',
      description: ticket.subject,
      type: 'ticket',
      href: `/helpdesk?record=${encodeURIComponent(ticket.id)}`,
    },
    `${student.fullName} opened ticket ${ticketNumber}`,
    'ticket'
  );
  res.status(201).json(ticket);
});

// @route POST /api/portal/tickets/:id/replies
export const replyToTicket = asyncHandler(async (req, res) => {
  const student = await currentStudent(req);
  const ticket = await Ticket.findOne({ _id: String(req.params.id), studentNumber: student.studentId });
  if (!ticket) throw new HttpError(404, 'Ticket not found.');
  if (ticket.status === 'Resolved') throw new HttpError(409, 'This ticket is resolved. Open a new ticket instead.');
  ticket.replies.push({
    id: randomUUID(),
    author: student.fullName,
    message: req.body.message,
    timestamp: nowIso(),
    isAdmin: false,
  });
  ticket.dateUpdated = today();
  await ticket.save();
  res.json(ticket);
});
