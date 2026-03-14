import { appSchema, tableSchema } from '@nozbe/watermelondb';

/**
 * WatermelonDB schema — mirrors the PostgreSQL tables used by SyncController.
 *
 * Column names match WatermelonDB convention (snake_case). The sync layer maps
 * these to the mobile-side field names via Model definitions below.
 *
 * Sync table mapping (WatermelonDB → PostgreSQL):
 *   meal_logs    → food_logs
 *   workout_logs → workout_logs
 *   body_metrics → body_metrics
 *   step_logs    → step_logs
 */
export default appSchema({
  version: 1,
  tables: [
    tableSchema({
      name: 'meal_logs',
      columns: [
        { name: 'dish_name',  type: 'string' },
        { name: 'calories',   type: 'number' },
        { name: 'protein_g',  type: 'number' },
        { name: 'carbs_g',    type: 'number' },
        { name: 'fats_g',     type: 'number' },
        { name: 'date',       type: 'string', isOptional: true },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'workout_logs',
      columns: [
        { name: 'exercise_name', type: 'string' },
        { name: 'sets',          type: 'number' },
        { name: 'reps',          type: 'number' },
        { name: 'weight_kg',     type: 'number', isOptional: true },
        { name: 'date',          type: 'string', isOptional: true },
        { name: 'updated_at',    type: 'number' },
      ],
    }),
    tableSchema({
      name: 'body_metrics',
      columns: [
        { name: 'weight_kg',    type: 'number', isOptional: true },
        { name: 'height_cm',    type: 'number', isOptional: true },
        { name: 'bmi',          type: 'number', isOptional: true },
        { name: 'body_fat_pct', type: 'number', isOptional: true },
        { name: 'recorded_at',  type: 'string', isOptional: true },
        { name: 'updated_at',   type: 'number' },
      ],
    }),
    tableSchema({
      name: 'step_logs',
      columns: [
        { name: 'steps',      type: 'number' },
        { name: 'date',       type: 'string', isOptional: true },
        { name: 'updated_at', type: 'number' },
      ],
    }),
  ],
});
