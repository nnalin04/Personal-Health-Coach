/**
 * WatermelonDB ↔ Server two-phase sync.
 *
 * Uses the WatermelonDB `synchronize()` helper which handles the pull/push
 * protocol automatically. The server endpoints match SyncController:
 *   GET  /api/v1/sync/pull?lastPulledAt={ms}  → changes + timestamp
 *   POST /api/v1/sync/push                    → apply local changes
 *
 * Call `syncDatabase()` on app foreground or after a data mutation.
 */
import { synchronize } from '@nozbe/watermelondb/sync';
import { database } from '../db';
import apiClient from './apiClient';

export async function syncDatabase(): Promise<void> {
  await synchronize({
    database,

    pullChanges: async ({ lastPulledAt }) => {
      const params = lastPulledAt ? `?lastPulledAt=${lastPulledAt}` : '';
      const res = await apiClient.get(`/v1/sync/pull${params}`);
      const { changes, timestamp } = res.data as {
        changes: Record<string, { created: object[]; updated: object[]; deleted: string[] }>;
        timestamp: number;
      };
      return { changes, timestamp };
    },

    pushChanges: async ({ changes, lastPulledAt: _ }) => {
      await apiClient.post('/v1/sync/push', changes);
    },

    migrationsEnabledAtVersion: 1,
  });
}
