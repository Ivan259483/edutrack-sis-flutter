import express from 'express';
import { bootstrap, readSettings, updateSettings } from '../controllers/adminController.js';
import * as resources from '../controllers/resourceControllers.js';
import { authorize, protect } from '../middleware/auth.js';
import { mountCrud } from '../utils/crud.js';
import * as rules from '../validators/index.js';

const router = express.Router();
const adminOnly = [protect, authorize('admin')];

const crud = (controller, validation) => mountCrud(express.Router(), controller, validation);

// Settings are readable by any signed-in user; only admins can change them.
router.get('/settings', protect, readSettings);
router.put('/settings', adminOnly, rules.settingsRules, updateSettings);
// Subject catalog: readable by any signed-in user, managed by admins.
router.get('/subjects', protect, resources.subjects.list);

router.use(adminOnly);
router.get('/admin/bootstrap', bootstrap);
router.use('/students', crud(resources.students, rules.studentRules));
router.use('/enrollments', crud(resources.enrollments, rules.enrollmentRules));
router.use('/grades', crud(resources.grades, rules.gradeRules));
router.use('/schedules', crud(resources.schedules, rules.scheduleRules));
router.use('/announcements', crud(resources.announcements, rules.announcementRules));
router.use('/tickets', crud(resources.tickets, rules.ticketRules));
router.use('/notifications', crud(resources.notifications, rules.notificationRules));
router.use('/activity-logs', crud(resources.activityLogs, rules.activityLogRules));
router.use('/subjects', crud(resources.subjects, rules.subjectRules));

export default router;
