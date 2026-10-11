import express from 'express';
import * as portal from '../controllers/portalController.js';
import { authorize, protect } from '../middleware/auth.js';
import {
  portalEnrollmentRules,
  portalProfileRules,
  portalReplyRules,
  portalTicketRules,
} from '../validators/index.js';

// Student-only endpoints used by the EduTrack student portal.
const router = express.Router();
router.use(protect, authorize('student'));

router.route('/profile').get(portal.getProfile).put(portalProfileRules, portal.updateProfile);
router.get('/subjects', portal.getSubjects);
router
  .route('/enrollment')
  .get(portal.getEnrollment)
  .post(portalEnrollmentRules, portal.submitEnrollment)
  .delete(portal.cancelEnrollment);
router.get('/grades', portal.getGrades);
router.get('/schedule', portal.getSchedule);
router.get('/announcements', portal.getAnnouncements);
router.route('/tickets').get(portal.getTickets).post(portalTicketRules, portal.createTicket);
router.post('/tickets/:id/replies', portalReplyRules, portal.replyToTicket);

export default router;
