ALTER TABLE `CleanupJobItem`
  ADD COLUMN `sizeBytes` INTEGER NOT NULL DEFAULT 0;

CREATE INDEX `CleanupJobItem_status_processedAt_idx`
  ON `CleanupJobItem`(`status`, `processedAt`);
