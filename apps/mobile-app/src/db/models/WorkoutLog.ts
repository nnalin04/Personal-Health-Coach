import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class WorkoutLog extends Model {
  static table = 'workout_logs';

  @field('exercise_name') exerciseName!: string;
  @field('sets')          sets!:         number;
  @field('reps')          reps!:         number;
  @field('weight_kg')     weightKg!:     number;
  @field('date')          date!:         string;
  @readonly @date('updated_at') updatedAt!: Date;
}
