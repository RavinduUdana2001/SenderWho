ALTER TABLE `User` ADD COLUMN `yahooSubject` VARCHAR(255) NULL;
CREATE UNIQUE INDEX `User_yahooSubject_key` ON `User`(`yahooSubject`);
