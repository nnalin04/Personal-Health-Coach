import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class MealLog extends Model {
  static table = 'meal_logs';

  @field('dish_name')  dishName!: string;
  @field('calories')   calories!: number;
  @field('protein_g')  proteinG!: number;
  @field('carbs_g')    carbsG!:   number;
  @field('fats_g')     fatsG!:    number;
  @field('date')       date!:     string;
  @readonly @date('updated_at') updatedAt!: Date;
}
