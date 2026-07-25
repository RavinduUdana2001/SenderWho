CREATE INDEX `Message_userId_isTrashed_isArchived_receivedAt_idx`
ON `Message`(`userId`, `isTrashed`, `isArchived`, `receivedAt`);

CREATE INDEX `Message_userId_isRead_receivedAt_idx`
ON `Message`(`userId`, `isRead`, `receivedAt`);
