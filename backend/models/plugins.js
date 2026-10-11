import { randomUUID } from 'node:crypto';

// String IDs keep record links (e.g. enrollment.studentId -> student.id) identical
// between MongoDB and both React portals.
export const recordFields = {
  _id: { type: String, default: () => randomUUID() },
  // Newest first: list endpoints sort by this so the UI order is stable.
  sortKey: { type: Number, default: () => Date.now(), select: false },
};

export const PROGRAMS = ['BSIT', 'BSBA', 'BSEd'];
export const PROGRAM_NAMES = {
  BSIT: 'BS Information Technology',
  BSBA: 'BS Business Administration',
  BSEd: 'Bachelor of Secondary Education',
};
export const YEAR_LEVELS = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
export const SEMESTERS = ['1st Semester', '2nd Semester', 'Summer'];
export const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

// Expose `id` instead of Mongo's `_id`/`__v` in every JSON response.
export function clientJson(schema, hidden = []) {
  schema.set('toJSON', {
    versionKey: false,
    transform: (_doc, ret) => {
      ret.id = ret._id;
      delete ret._id;
      delete ret.sortKey;
      for (const key of hidden) delete ret[key];
      return ret;
    },
  });
}
