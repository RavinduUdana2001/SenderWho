-- Store the category on each message. A sender can legitimately send both
-- receipts and promotions, so sender-level category alone is not accurate.
ALTER TABLE `Message`
    ADD COLUMN `category` ENUM('IMPORTANT', 'PEOPLE', 'ORDERS', 'FINANCE', 'NEWSLETTERS', 'PROMOTIONS', 'TRAVEL', 'SOCIAL', 'SPAM', 'UNKNOWN') NOT NULL DEFAULT 'UNKNOWN';

-- Backfill existing metadata using the same deterministic rules as the Gmail
-- synchronization worker. Future scans update this value directly.
UPDATE `Message`
SET `category` = CASE
    WHEN JSON_CONTAINS(`labels`, '"SPAM"') THEN 'SPAM'
    WHEN JSON_CONTAINS(`labels`, '"CATEGORY_PROMOTIONS"') THEN 'PROMOTIONS'
    WHEN JSON_CONTAINS(`labels`, '"CATEGORY_SOCIAL"') THEN 'SOCIAL'
    WHEN JSON_CONTAINS(`labels`, '"CATEGORY_PERSONAL"') THEN 'PEOPLE'
    WHEN JSON_CONTAINS(`labels`, '"IMPORTANT"') THEN 'IMPORTANT'
    WHEN LOWER(COALESCE(`subject`, '')) REGEXP 'newsletter|digest|weekly update' THEN 'NEWSLETTERS'
    WHEN LOWER(COALESCE(`subject`, '')) REGEXP 'invoice|receipt|payment|bank|statement' THEN 'FINANCE'
    WHEN LOWER(COALESCE(`subject`, '')) REGEXP 'order|shipped|delivery|purchase' THEN 'ORDERS'
    WHEN LOWER(COALESCE(`subject`, '')) REGEXP 'flight|hotel|booking|reservation|travel' THEN 'TRAVEL'
    ELSE 'UNKNOWN'
END;

CREATE INDEX `Message_userId_category_idx` ON `Message`(`userId`, `category`);
