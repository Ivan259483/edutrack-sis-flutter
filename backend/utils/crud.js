import { asyncHandler, HttpError } from '../middleware/error.js';

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Builds REST handlers for a Mongoose model.
 *   GET    /           list  (?search=&page=&limit=&<filterField>=)
 *   GET    /:id        read
 *   POST   /           create
 *   PUT    /:id        replace (validated fields only)
 *   DELETE /:id        delete
 * Hooks let each resource enforce its own business rules.
 */
export function crudController(
  Model,
  { searchFields = [], filterFields = [], beforeSave, afterSave, beforeDelete, afterDelete } = {}
) {
  const findOr404 = async (id) => {
    const doc = await Model.findById(String(id));
    if (!doc) throw new HttpError(404, `${Model.modelName} not found.`);
    return doc;
  };

  return {
    list: asyncHandler(async (req, res) => {
      const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
      const limit = Math.min(500, Math.max(1, Number.parseInt(req.query.limit, 10) || 50));
      const filter = {};
      for (const field of filterFields) {
        const value = req.query[field];
        if (typeof value === 'string' && value && value !== 'all') filter[field] = value;
      }
      const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
      if (search && searchFields.length) {
        const pattern = new RegExp(escapeRegex(search.slice(0, 100)), 'i');
        filter.$or = searchFields.map((field) => ({ [field]: pattern }));
      }
      const [items, total] = await Promise.all([
        Model.find(filter)
          .sort({ sortKey: -1 })
          .skip((page - 1) * limit)
          .limit(limit),
        Model.countDocuments(filter),
      ]);
      res.json({ items, page, limit, total, pages: Math.max(1, Math.ceil(total / limit)) });
    }),

    get: asyncHandler(async (req, res) => {
      res.json(await findOr404(req.params.id));
    }),

    create: asyncHandler(async (req, res) => {
      const { id, ...fields } = req.body;
      if (id && (await Model.exists({ _id: id }))) {
        throw new HttpError(409, `${Model.modelName} ${id} already exists.`);
      }
      const doc = new Model(id ? { _id: id, ...fields } : fields);
      await beforeSave?.({ doc, previous: null, req });
      await doc.save();
      await afterSave?.({ doc, previous: null, req });
      res.status(201).json(doc);
    }),

    update: asyncHandler(async (req, res) => {
      const doc = await findOr404(req.params.id);
      const previous = doc.toObject();
      const { id: _ignored, ...fields } = req.body;
      doc.set(fields);
      await beforeSave?.({ doc, previous, req });
      await doc.save();
      await afterSave?.({ doc, previous, req });
      res.json(doc);
    }),

    remove: asyncHandler(async (req, res) => {
      const doc = await findOr404(req.params.id);
      await beforeDelete?.({ doc, req });
      await doc.deleteOne();
      await afterDelete?.({ doc, req });
      res.json({ id: doc.id, deleted: true });
    }),
  };
}

// Wires a crudController onto an Express router.
export function mountCrud(router, controller, rules) {
  router.route('/').get(controller.list).post(rules, controller.create);
  router.route('/:id').get(controller.get).put(rules, controller.update).delete(controller.remove);
  return router;
}
