import mongoose from 'mongoose';
import { clientJson, recordFields } from './plugins.js';

// Admin-facing notifications (new enrollments, tickets, activity).
const notificationSchema = new mongoose.Schema(
  {
    ...recordFields,
    title: { type: String, required: true },
    description: { type: String, default: '' },
    timestamp: { type: String, required: true },
    read: { type: Boolean, default: false },
    type: { type: String, enum: ['enrollment', 'ticket', 'announcement', 'grade'], required: true },
    href: { type: String },
  },
  { timestamps: true }
);

clientJson(notificationSchema);

export default mongoose.model('Notification', notificationSchema);
