import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class StepLog extends Model {
  static table = 'step_logs';

  @field('steps') steps!: number;
  @field('date')  date!:  string;
  @readonly @date('updated_at') updatedAt!: Date;
}
