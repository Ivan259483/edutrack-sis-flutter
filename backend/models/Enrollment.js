import mongoose from 'mongoose';
import { clientJson, PROGRAMS, recordFields, YEAR_LEVELS } from './plugins.js';

const enrollmentSubjectSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    code: { type: String, required: true },
    title: { type: String, required: true },
    units: { type: Number, required: true, min: 1 },
    prerequisite: { type: String },
    hasPrerequisiteMet: { type: Boolean, default: true },
  },
  { _id: false }
);

const enrollmentSchema = new mongoose.Schema(
  {
    ...recordFields,
    studentId: { type: String, ref: 'Student', required: true }, // Student.id
    studentName: { type: String, required: true },
    studentNumber: { type: String, required: true },
    program: { type: String, enum: PROGRAMS, required: true },
    yearLevel: { type: String, enum: YEAR_LEVELS, required: true },
    section: { type: String, required: true },
    subjects: { type: [enrollmentSubjectSchema], default: [] },
    totalUnits: { type: Number, default: 0, min: 0 },
    status: { type: String, enum: ['Pending', 'Approved', 'Rejected'], default: 'Pending' },
    remarks: { type: String, default: '' },
    submittedDate: { type: String, required: true },
    hasPrerequisiteConcerns: { type: Boolean, default: false },
    prerequisiteOverride: { type: Boolean },
  },
  { timestamps: true }
);

enrollmentSchema.pre('validate', function () {
  this.totalUnits = this.subjects.reduce((sum, s) => sum + s.units, 0);
});

clientJson(enrollmentSchema);

export default mongoose.model('Enrollment', enrollmentSchema);
