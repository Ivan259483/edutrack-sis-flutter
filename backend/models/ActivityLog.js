import mongoose from 'mongoose';
import { clientJson, recordFields } from './plugins.js';

const activityLogSchema = new mongoose.Schema(
  {
    ...recordFields,
    action: { type: String, required: true },
    actor: { type: String, required: true },
    timestamp: { type: String, required: true },
    type: {
      type: String,
      enum: ['enrollment', 'grade', 'announcement', 'ticket', 'student', 'schedule', 'settings'],
      required: true,
    },
  },
  { timestamps: true }
);

clientJson(activityLogSchema);

export default mongoose.model('ActivityLog', activityLogSchema);
