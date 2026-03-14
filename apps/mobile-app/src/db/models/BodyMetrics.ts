import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class BodyMetrics extends Model {
  static table = 'body_metrics';

  @field('weight_kg')    weightKg!:   number;
  @field('height_cm')    heightCm!:   number;
  @field('bmi')          bmi!:        number;
  @field('body_fat_pct') bodyFatPct!: number;
  @field('recorded_at')  recordedAt!: string;
  @readonly @date('updated_at') updatedAt!: Date;
}
