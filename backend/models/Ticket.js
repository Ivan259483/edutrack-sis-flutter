import mongoose from 'mongoose';
import { clientJson, recordFields } from './plugins.js';

const replySchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    author: { type: String, required: true },
    message: { type: String, required: true },
    timestamp: { type: String, required: true },
    isAdmin: { type: Boolean, default: false },
  },
  { _id: false }
);

const ticketSchema = new mongoose.Schema(
  {
    ...recordFields,
    ticketNumber: { type: String, required: true, unique: true },
    studentName: { type: String, required: true },
    studentNumber: { type: String, required: true }, // Student.studentId
    category: {
      type: String,
      enum: ['Enrollment', 'Grades', 'Technical', 'General'],
      required: true,
    },
    subject: { type: String, required: true, trim: true },
    message: { type: String, required: true, trim: true },
    status: { type: String, enum: ['Open', 'In Progress', 'Resolved'], default: 'Open' },
    dateCreated: { type: String, required: true },
    dateUpdated: { type: String, required: true },
    replies: { type: [replySchema], default: [] },
  },
  { timestamps: true }
);

clientJson(ticketSchema);

export default mongoose.model('Ticket', ticketSchema);
