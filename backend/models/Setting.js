import mongoose from 'mongoose';
import { SEMESTERS } from './plugins.js';

// Single document holding the current academic period and portal switches.
const settingSchema = new mongoose.Schema(
  {
    _id: { type: String, default: 'system' },
    academicYear: { type: String, required: true, match: /^\d{4}-\d{4}$/ },
    semester: { type: String, enum: SEMESTERS, required: true },
    enrollmentOpen: { type: Boolean, default: true },
    gradeEncodingOpen: { type: Boolean, default: true },
    notifyNewEnrollments: { type: Boolean, default: true },
    notifyNewTickets: { type: Boolean, default: true },
    notifySystemActivity: { type: Boolean, default: false },
  },
  { timestamps: true }
);

settingSchema.set('toJSON', {
  versionKey: false,
  transform: (_doc, ret) => {
    delete ret._id;
    delete ret.createdAt;
    delete ret.updatedAt;
    return ret;
  },
});

const Setting = mongoose.model('Setting', settingSchema);

export const getSettings = async () =>
  (await Setting.findById('system')) ??
  Setting.create({ academicYear: '2024-2025', semester: '1st Semester' });

export default Setting;
