import mongoose from 'mongoose';
import { clientJson, recordFields } from './plugins.js';

// Course catalog used for enrollment.
const subjectSchema = new mongoose.Schema(
  {
    ...recordFields,
    code: { type: String, required: true, unique: true, uppercase: true, trim: true },
    title: { type: String, required: true, trim: true },
    units: { type: Number, required: true, min: 1, max: 6 },
    prerequisite: { type: String, uppercase: true, trim: true },
    description: { type: String, default: '' },
  },
  { timestamps: true }
);

clientJson(subjectSchema);

export default mongoose.model('Subject', subjectSchema);
