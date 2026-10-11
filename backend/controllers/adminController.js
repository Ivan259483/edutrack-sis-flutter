import ActivityLog from '../models/ActivityLog.js';
import Announcement from '../models/Announcement.js';
import Enrollment from '../models/Enrollment.js';
import Grade from '../models/Grade.js';
import Notification from '../models/Notification.js';
import Schedule from '../models/Schedule.js';
import Setting, { getSettings } from '../models/Setting.js';
import Student from '../models/Student.js';
import Subject from '../models/Subject.js';
import Ticket from '../models/Ticket.js';
import { asyncHandler } from '../middleware/error.js';
import { knownSections } from './resourceControllers.js';

const newestFirst = { sortKey: -1 };

// @desc    Everything the admin portal needs on load, in one request
// @route   GET /api/admin/bootstrap
// @access  Admin
export const bootstrap = asyncHandler(async (_req, res) => {
  const [students, enrollments, grades, schedules, announcements, tickets, notifications, activityLogs, subjects, settings, sections] =
    await Promise.all([
      Student.find().sort(newestFirst),
      Enrollment.find().sort(newestFirst),
      Grade.find().sort(newestFirst),
      Schedule.find().sort(newestFirst),
      Announcement.find().sort(newestFirst),
      Ticket.find().sort(newestFirst),
      Notification.find().sort(newestFirst).limit(200),
      ActivityLog.find().sort(newestFirst).limit(200),
      Subject.find().sort({ code: 1 }),
      getSettings(),
      knownSections(),
    ]);
  res.json({
    state: { students, enrollments, grades, schedules, announcements, tickets, notifications, activityLogs, settings },
    subjects,
    sections,
  });
});

// @desc    Current academic period and portal switches
// @route   GET /api/settings
// @access  Signed-in users (students need to know if enrollment is open)
export const readSettings = asyncHandler(async (_req, res) => {
  res.json(await getSettings());
});

// @desc    Update settings
// @route   PUT /api/settings
// @access  Admin
export const updateSettings = asyncHandler(async (req, res) => {
  await getSettings();
  const settings = await Setting.findByIdAndUpdate('system', req.body, {
    new: true,
    runValidators: true,
  });
  res.json(settings);
});
