// Business rules enforced by the API. They mirror the admin portal's client
// checks so the database stays consistent no matter which client writes.
import { HttpError } from '../middleware/error.js';
import { PROGRAMS, YEAR_LEVELS } from '../models/plugins.js';

export const normalize = (value) => String(value).trim().replace(/\s+/g, ' ').toLowerCase();

export const initials = (name) =>
  name
    .trim()
    .split(/\s+/)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

// Today's date (YYYY-MM-DD) in the Philippines, matching the admin portal.
export const today = (date = new Date()) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);

export const nowIso = () => new Date().toISOString();

export function assertSectionMatches({ program, yearLevel, section }) {
  if (!section.startsWith(`${program} ${yearLevel[0]}`)) {
    throw new HttpError(400, 'Section must match the selected program and year level.');
  }
}

export const isValidGrade = (g) => typeof g === 'number' && Number.isFinite(g) && g >= 1 && g <= 5;
export const canPublishGrade = (g) =>
  isValidGrade(g.finalGrade) && (g.midtermGrade === null || isValidGrade(g.midtermGrade));

export const hasPrerequisiteConcerns = (e) =>
  e.hasPrerequisiteConcerns || e.subjects.some((s) => !s.hasPrerequisiteMet);

export function assertEnrollmentTransition(previous, next) {
  if (previous && previous.status !== next.status && previous.status !== 'Pending') {
    throw new HttpError(409, 'Only pending enrollments can be reviewed.');
  }
  if (next.status === 'Approved' && hasPrerequisiteConcerns(next) && !next.prerequisiteOverride) {
    throw new HttpError(400, 'Confirm the prerequisite override before approval.');
  }
  if (next.status === 'Rejected' && !next.remarks.trim()) {
    throw new HttpError(400, 'Rejection remarks are required.');
  }
}

const toMinutes = (time) => {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
};

export function assertScheduleValid(item, others) {
  const start = toMinutes(item.startTime);
  const end = toMinutes(item.endTime);
  if (start >= end) throw new HttpError(400, 'Start time must be before end time.');
  if (start < 420 || end > 1080) throw new HttpError(400, 'Classes must be within 07:00–18:00.');
  const overlapping = others.filter(
    (s) =>
      s.id !== item.id &&
      s.day === item.day &&
      toMinutes(s.startTime) < end &&
      start < toMinutes(s.endTime)
  );
  const reasons = ['room', 'instructor', 'section'].filter((key) =>
    overlapping.some((s) => normalize(s[key]) === normalize(item[key]))
  );
  if (reasons.length) {
    throw new HttpError(
      409,
      `Schedule conflict: ${reasons.join(', ')} already booked on ${item.day} at that time.`
    );
  }
}

export function assertAnnouncementTarget({ targetAudience, targetValue }, sections) {
  const allowed = {
    'All Students': ['All Students'],
    'Specific Program': PROGRAMS,
    'Specific Year Level': YEAR_LEVELS,
    'Specific Section': sections,
  };
  if (!allowed[targetAudience]?.includes(targetValue)) {
    throw new HttpError(400, `Choose a valid value for ${targetAudience.toLowerCase()}.`);
  }
}

// Does a published announcement target this student?
export const announcementTargets = (a, student) =>
  a.targetAudience === 'All Students' ||
  (a.targetAudience === 'Specific Program' && a.targetValue === student.program) ||
  (a.targetAudience === 'Specific Year Level' && a.targetValue === student.yearLevel) ||
  (a.targetAudience === 'Specific Section' && a.targetValue === student.section);
