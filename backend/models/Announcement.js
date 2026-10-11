import mongoose from 'mongoose';
import { clientJson, recordFields } from './plugins.js';

const announcementSchema = new mongoose.Schema(
  {
    ...recordFields,
    title: { type: String, required: true, trim: true },
    category: {
      type: String,
      enum: ['Academic', 'Enrollment', 'Event', 'General', 'Urgent'],
      required: true,
    },
    message: { type: String, required: true, trim: true },
    targetAudience: {
      type: String,
      enum: ['All Students', 'Specific Program', 'Specific Year Level', 'Specific Section'],
      required: true,
    },
    targetValue: { type: String, required: true },
    status: { type: String, enum: ['Draft', 'Published'], default: 'Draft' },
    author: { type: String, required: true },
    dateCreated: { type: String, required: true },
    datePublished: { type: String, default: null },
  },
  { timestamps: true }
);

clientJson(announcementSchema);

export default mongoose.model('Announcement', announcementSchema);
