import mongoose from 'mongoose';
import { clientJson, PROGRAMS, recordFields } from './plugins.js';

const grade = { type: Number, min: 1, max: 5, default: null };

const gradeSchema = new mongoose.Schema(
  {
    ...recordFields,
    studentId: { type: String, ref: 'Student', required: true }, // Student.id
    studentName: { type: String, required: true },
    studentNumber: { type: String, required: true },
    subjectCode: { type: String, required: true, uppercase: true, trim: true },
    subjectTitle: { type: String, required: true, trim: true },
    section: { type: String, required: true },
    program: { type: String, enum: PROGRAMS, required: true },
    midtermGrade: grade,
    finalGrade: grade,
    numericalGrade: grade,
    remark: { type: String, enum: ['Passed', 'Failed', 'Incomplete'], default: 'Incomplete' },
    units: { type: Number, required: true, min: 1, max: 6 },
    publishStatus: { type: String, enum: ['Draft', 'Published'], default: 'Draft' },
    semester: { type: String, required: true },
    academicYear: { type: String, required: true },
  },
  { timestamps: true }
);

// Philippine grading scale: 1.00-3.00 passes; the final grade is the official grade.
gradeSchema.pre('validate', function () {
  this.numericalGrade = this.finalGrade;
  this.remark =
    this.finalGrade === null ? 'Incomplete' : this.finalGrade <= 3 ? 'Passed' : 'Failed';
});

clientJson(gradeSchema);

export default mongoose.model('Grade', gradeSchema);
