import { body } from 'express-validator';
import { DAYS, PROGRAMS, SEMESTERS, YEAR_LEVELS } from '../models/plugins.js';
import { validate } from '../middleware/validate.js';

const text = (field, max = 200) =>
  body(field)
    .isString()
    .withMessage('must be text')
    .trim()
    .notEmpty()
    .withMessage('is required')
    .isLength({ max })
    .withMessage(`must be at most ${max} characters`);
const optionalText = (field, max = 2000) =>
  body(field).optional().isString().withMessage('must be text').trim().isLength({ max });
const oneOf = (field, values) =>
  body(field).isIn(values).withMessage(`must be one of: ${values.join(', ')}`);
const bool = (field) => body(field).isBoolean({ strict: true }).withMessage('must be true or false');
const nullableGrade = (field) =>
  body(field)
    .custom((v) => v === null || (typeof v === 'number' && Number.isFinite(v) && v >= 1 && v <= 5))
    .withMessage('must be null or a number from 1.00 to 5.00');
const time = (field) =>
  body(field).matches(/^([01]\d|2[0-3]):[0-5]\d$/).withMessage('must be a time in HH:MM format');
// Clients may choose their own record id (the admin portal does); otherwise MongoDB generates one.
const clientId = body('id')
  .optional()
  .isString()
  .matches(/^[\w-]{1,64}$/)
  .withMessage('must be 1-64 letters, numbers, dashes or underscores');

export const studentRules = [
  clientId,
  text('studentId', 30),
  text('fullName', 120),
  body('email').isEmail().withMessage('must be a valid email').customSanitizer((v) => String(v).trim().toLowerCase()),
  text('contactNumber', 40),
  text('address', 300),
  text('emergencyContact', 120),
  text('emergencyContactNumber', 40),
  oneOf('program', PROGRAMS),
  oneOf('yearLevel', YEAR_LEVELS),
  text('section', 30),
  oneOf('academicStatus', ['Active', 'On Leave', 'Graduated', 'Suspended']),
  text('dateEnrolled', 40),
  optionalText('avatarInitials', 4),
  validate,
];

const subjectItem = (prefix) => [
  text(`${prefix}.id`, 64),
  text(`${prefix}.code`, 20),
  text(`${prefix}.title`, 150),
  body(`${prefix}.units`).isInt({ min: 1, max: 6 }).withMessage('must be 1-6 units').toInt(),
  optionalText(`${prefix}.prerequisite`, 20),
];

export const enrollmentRules = [
  clientId,
  text('studentId', 64),
  text('studentName', 120),
  text('studentNumber', 30),
  oneOf('program', PROGRAMS),
  oneOf('yearLevel', YEAR_LEVELS),
  text('section', 30),
  body('subjects').isArray({ max: 15 }).withMessage('must be a list of at most 15 subjects'),
  ...subjectItem('subjects.*'),
  bool('subjects.*.hasPrerequisiteMet'),
  oneOf('status', ['Pending', 'Approved', 'Rejected']),
  body('remarks').isString().trim().isLength({ max: 1000 }),
  text('submittedDate', 40),
  bool('hasPrerequisiteConcerns'),
  body('prerequisiteOverride').optional().isBoolean({ strict: true }),
  validate,
];

export const gradeRules = [
  clientId,
  text('studentId', 64),
  text('studentName', 120),
  text('studentNumber', 30),
  text('subjectCode', 20),
  text('subjectTitle', 150),
  text('section', 30),
  oneOf('program', PROGRAMS),
  nullableGrade('midtermGrade'),
  nullableGrade('finalGrade'),
  body('units').isInt({ min: 1, max: 6 }).withMessage('must be 1-6 units').toInt(),
  oneOf('publishStatus', ['Draft', 'Published']),
  text('semester', 30),
  text('academicYear', 9),
  validate,
];

export const scheduleRules = [
  clientId,
  text('subjectCode', 20),
  text('subjectTitle', 150),
  text('section', 30),
  oneOf('program', PROGRAMS),
  text('instructor', 120),
  oneOf('day', DAYS),
  time('startTime'),
  time('endTime'),
  text('room', 60),
  validate,
];

export const announcementRules = [
  clientId,
  text('title', 200),
  oneOf('category', ['Academic', 'Enrollment', 'Event', 'General', 'Urgent']),
  text('message', 5000),
  oneOf('targetAudience', ['All Students', 'Specific Program', 'Specific Year Level', 'Specific Section']),
  text('targetValue', 60),
  oneOf('status', ['Draft', 'Published']),
  text('author', 120),
  text('dateCreated', 40),
  body('datePublished')
    .custom((v) => v === null || (typeof v === 'string' && v.length <= 40))
    .withMessage('must be null or a date'),
  validate,
];

const replyRules = [
  text('replies.*.id', 64),
  text('replies.*.author', 120),
  text('replies.*.message', 5000),
  text('replies.*.timestamp', 40),
  bool('replies.*.isAdmin'),
];

export const ticketRules = [
  clientId,
  text('ticketNumber', 30),
  text('studentName', 120),
  text('studentNumber', 30),
  oneOf('category', ['Enrollment', 'Grades', 'Technical', 'General']),
  text('subject', 200),
  text('message', 5000),
  oneOf('status', ['Open', 'In Progress', 'Resolved']),
  text('dateCreated', 40),
  text('dateUpdated', 40),
  body('replies').isArray({ max: 200 }),
  ...replyRules,
  validate,
];

export const notificationRules = [
  clientId,
  text('title', 200),
  body('description').isString().isLength({ max: 500 }),
  text('timestamp', 40),
  bool('read'),
  oneOf('type', ['enrollment', 'ticket', 'announcement', 'grade']),
  body('href')
    .optional()
    .matches(/^\/(?:students|enrollment|grades|schedules|announcements|helpdesk|settings)?(?:\?record=[\w%-]+)?$/)
    .withMessage('must be an internal admin link'),
  validate,
];

export const activityLogRules = [
  clientId,
  text('action', 300),
  text('actor', 120),
  text('timestamp', 40),
  oneOf('type', ['enrollment', 'grade', 'announcement', 'ticket', 'student', 'schedule', 'settings']),
  validate,
];

export const subjectRules = [
  clientId,
  text('code', 20),
  text('title', 150),
  body('units').isInt({ min: 1, max: 6 }).toInt(),
  optionalText('prerequisite', 20),
  optionalText('description', 1000),
  validate,
];

export const settingsRules = [
  body('academicYear')
    .matches(/^\d{4}-\d{4}$/)
    .withMessage('use YYYY-YYYY')
    .custom((v) => Number(v.slice(5)) === Number(v.slice(0, 4)) + 1)
    .withMessage('must span consecutive years'),
  oneOf('semester', SEMESTERS),
  bool('enrollmentOpen'),
  bool('gradeEncodingOpen'),
  bool('notifyNewEnrollments'),
  bool('notifyNewTickets'),
  bool('notifySystemActivity'),
  validate,
];

// ─── Auth ────────────────────────────────────────────────────────────
const password = body('password')
  .isString()
  .isLength({ min: 8, max: 128 })
  .withMessage('must be 8-128 characters')
  .matches(/[A-Za-z]/)
  .withMessage('must contain a letter')
  .matches(/\d/)
  .withMessage('must contain a number');
const email = body('email').isEmail().withMessage('must be a valid email').customSanitizer((v) => String(v).trim().toLowerCase());

export const loginRules = [
  text('identifier', 120),
  body('password').isString().notEmpty().withMessage('is required').isLength({ max: 128 }),
  body('role').optional().isIn(['admin', 'student']),
  validate,
];
export const sendOtpRules = [email, validate];
export const verifyOtpRules = [email, body('otp').isString().trim().matches(/^\d{5}$/).withMessage('must be 5 digits'), validate];
export const registerRules = [
  email,
  text('firstName', 60),
  text('lastName', 60),
  password,
  body('program')
    .isIn([...PROGRAMS, 'BS Information Technology', 'BS Business Administration', 'Bachelor of Secondary Education'])
    .withMessage('is not an offered program'),
  oneOf('yearLevel', YEAR_LEVELS),
  validate,
];
export const changePasswordRules = [
  body('currentPassword').isString().notEmpty().withMessage('is required'),
  // The new password is sent as `password` so the same strength rule applies.
  password,
  validate,
];

export const portalEnrollmentRules = [
  body('subjectCodes').isArray({ min: 1, max: 12 }).withMessage('select 1-12 subjects'),
  body('subjectCodes.*').isString().trim().matches(/^[A-Z]{2,4}\d{3}$/i).withMessage('invalid subject code'),
  validate,
];
export const portalTicketRules = [
  oneOf('category', ['Enrollment', 'Grades', 'Technical', 'General']),
  text('subject', 200),
  text('message', 5000),
  validate,
];
export const portalReplyRules = [text('message', 5000), validate];

// Students may edit only their contact details. matchedData() in `validate`
// drops every other field (role, studentId, fullName, program, ...).
const phone = (field) =>
  text(field, 30).matches(/^\+?[0-9][0-9 ()-]{6,24}$/).withMessage('must be a valid phone number');
export const portalProfileRules = [
  phone('contactNumber'),
  text('address', 300),
  body('personalEmail')
    .optional()
    .isString()
    .withMessage('must be text')
    .trim()
    .toLowerCase()
    .if((value) => value !== '')
    .isEmail()
    .withMessage('must be a valid email'),
  text('emergencyContact', 120),
  phone('emergencyContactNumber'),
  optionalText('guardianRelationship', 60),
  validate,
];
