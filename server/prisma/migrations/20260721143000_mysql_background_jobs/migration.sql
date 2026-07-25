CREATE TABLE `BackgroundJob` (
    `id` VARCHAR(191) NOT NULL,
    `queue` VARCHAR(40) NOT NULL,
    `taskName` VARCHAR(80) NOT NULL,
    `payload` JSON NOT NULL,
    `status` ENUM('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELED') NOT NULL DEFAULT 'QUEUED',
    `attempts` INTEGER NOT NULL DEFAULT 0,
    `maxAttempts` INTEGER NOT NULL DEFAULT 1,
    `backoffMs` INTEGER NOT NULL DEFAULT 0,
    `availableAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `leaseOwner` VARCHAR(120) NULL,
    `leaseExpiresAt` DATETIME(3) NULL,
    `progress` JSON NULL,
    `result` JSON NULL,
    `lastError` TEXT NULL,
    `startedAt` DATETIME(3) NULL,
    `completedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `BackgroundJob_queue_status_availableAt_idx`(`queue`, `status`, `availableAt`),
    INDEX `BackgroundJob_status_leaseExpiresAt_idx`(`status`, `leaseExpiresAt`),
    INDEX `BackgroundJob_completedAt_idx`(`completedAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `ApiRateLimit` (
    `key` VARCHAR(191) NOT NULL,
    `totalHits` INTEGER NOT NULL DEFAULT 0,
    `expiresAt` DATETIME(3) NOT NULL,
    `blockedUntil` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `ApiRateLimit_expiresAt_idx`(`expiresAt`),
    INDEX `ApiRateLimit_blockedUntil_idx`(`blockedUntil`),
    PRIMARY KEY (`key`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
