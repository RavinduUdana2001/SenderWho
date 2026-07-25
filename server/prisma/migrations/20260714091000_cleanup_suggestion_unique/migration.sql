-- Keep the newest suggestion if an older deployment created duplicates.
DELETE older
FROM `CleanupSuggestion` AS older
INNER JOIN `CleanupSuggestion` AS newer
  ON older.`emailAccountId` = newer.`emailAccountId`
  AND older.`category` = newer.`category`
  AND (
    older.`createdAt` < newer.`createdAt`
    OR (older.`createdAt` = newer.`createdAt` AND older.`id` < newer.`id`)
  );

-- Make suggestion refreshes idempotent across concurrent workers.
CREATE UNIQUE INDEX `CleanupSuggestion_emailAccountId_category_key`
ON `CleanupSuggestion`(`emailAccountId`, `category`);
