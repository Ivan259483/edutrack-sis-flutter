// Strips keys like `$gt` or `a.b` from request input so user data can never
// become a MongoDB query operator (NoSQL injection).
const clean = (value) => {
  if (Array.isArray(value)) return value.map(clean);
  if (value && typeof value === 'object') {
    for (const key of Object.keys(value)) {
      if (key.startsWith('$') || key.includes('.')) delete value[key];
      else value[key] = clean(value[key]);
    }
  }
  return value;
};

export const sanitize = (req, _res, next) => {
  clean(req.body);
  clean(req.params);
  // Express 4 exposes req.query as a plain object we can clean in place.
  clean(req.query);
  next();
};
