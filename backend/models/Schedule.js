import mongoose from 'mongoose';
import { clientJson, DAYS, PROGRAMS, recordFields } from './plugins.js';

const time = { type: String, required: true, match: /^([01]\d|2[0-3]):[0-5]\d$/ };

const scheduleSchema = new mongoose.Schema(
  {
    ...recordFields,
    subjectCode: { type: String, required: true, trim: true },
    subjectTitle: { type: String, required: true, trim: true },
    section: { type: String, required: true, trim: true },
    program: { type: String, enum: PROGRAMS, required: true },
    instructor: { type: String, required: true, trim: true },
    day: { type: String, enum: DAYS, required: true },
    startTime: time,
    endTime: time,
    room: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

clientJson(scheduleSchema);

export default mongoose.model('Schedule', scheduleSchema);
