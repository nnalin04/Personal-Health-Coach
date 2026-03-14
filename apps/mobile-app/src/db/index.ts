import { Database } from '@nozbe/watermelondb';
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite';

import schema from './schema';
import MealLog    from './models/MealLog';
import WorkoutLog from './models/WorkoutLog';
import BodyMetrics from './models/BodyMetrics';
import StepLog    from './models/StepLog';

const adapter = new SQLiteAdapter({
  schema,
  dbName: 'HealthCoachDB',
  jsi: true,           // JSI mode for better perf on Hermes
  onSetUpError: (error) => {
    console.error('[WatermelonDB] setup error:', error);
  },
});

export const database = new Database({
  adapter,
  modelClasses: [MealLog, WorkoutLog, BodyMetrics, StepLog],
});

export { MealLog, WorkoutLog, BodyMetrics, StepLog };
