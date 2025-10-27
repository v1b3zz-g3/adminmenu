-- RX Reports Database Schema
-- Compatible with MySQL 5.7+ and MariaDB 10.2+

CREATE TABLE IF NOT EXISTS `rx_tickets` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ticket_number` VARCHAR(20) NOT NULL UNIQUE,
    `form_id` VARCHAR(50) NOT NULL,
    `reporter_identifier` VARCHAR(50) NOT NULL,
    `reporter_name` VARCHAR(100) NOT NULL,
    `reported_identifier` VARCHAR(50) DEFAULT NULL,
    `reported_name` VARCHAR(100) DEFAULT NULL,
    `priority` ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
    `status` ENUM('open', 'claimed', 'pending', 'closed', 'reopened') NOT NULL DEFAULT 'open',
    `claimed_by` VARCHAR(50) DEFAULT NULL,
    `claimed_by_name` VARCHAR(100) DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    `form_data` LONGTEXT NOT NULL,
    `rating` TINYINT(1) DEFAULT NULL CHECK (`rating` >= 1 AND `rating` <= 5),
    `rating_comment` TEXT DEFAULT NULL,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ticket_number` (`ticket_number`),
    KEY `idx_reporter` (`reporter_identifier`),
    KEY `idx_reported` (`reported_identifier`),
    KEY `idx_status` (`status`),
    KEY `idx_claimed_by` (`claimed_by`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_priority_status` (`priority`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_ticket_messages` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ticket_id` INT(11) NOT NULL,
    `sender_identifier` VARCHAR(50) NOT NULL,
    `sender_name` VARCHAR(100) NOT NULL,
    `sender_type` ENUM('player', 'staff', 'system') NOT NULL DEFAULT 'player',
    `message` TEXT NOT NULL,
    `is_quick_response` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ticket_id` (`ticket_id`),
    KEY `idx_created_at` (`created_at`),
    CONSTRAINT `fk_messages_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `rx_tickets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_ticket_actions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ticket_id` INT(11) NOT NULL,
    `action_id` VARCHAR(50) NOT NULL,
    `action_label` VARCHAR(100) NOT NULL,
    `staff_identifier` VARCHAR(50) NOT NULL,
    `staff_name` VARCHAR(100) NOT NULL,
    `target_identifier` VARCHAR(50) DEFAULT NULL,
    `target_name` VARCHAR(100) DEFAULT NULL,
    `metadata` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ticket_id` (`ticket_id`),
    KEY `idx_staff` (`staff_identifier`),
    KEY `idx_created_at` (`created_at`),
    CONSTRAINT `fk_actions_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `rx_tickets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_player_blocks` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `player_identifier` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `blocked_by` VARCHAR(50) NOT NULL,
    `blocked_by_name` VARCHAR(100) NOT NULL,
    `duration_days` INT(11) NOT NULL DEFAULT 0,
    `is_permanent` TINYINT(1) NOT NULL DEFAULT 0,
    `blocked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `unblocked_at` TIMESTAMP NULL DEFAULT NULL,
    `unblocked_by` VARCHAR(50) DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `idx_player` (`player_identifier`),
    KEY `idx_active` (`is_active`),
    KEY `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_player_notes` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `player_identifier` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `note` TEXT NOT NULL,
    `created_by` VARCHAR(50) NOT NULL,
    `created_by_name` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player` (`player_identifier`),
    KEY `idx_created_by` (`created_by`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_staff_stats` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `staff_identifier` VARCHAR(50) NOT NULL UNIQUE,
    `staff_name` VARCHAR(100) NOT NULL,
    `tickets_claimed` INT(11) NOT NULL DEFAULT 0,
    `tickets_closed` INT(11) NOT NULL DEFAULT 0,
    `total_rating` INT(11) NOT NULL DEFAULT 0,
    `rating_count` INT(11) NOT NULL DEFAULT 0,
    `average_rating` DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    `total_response_time` BIGINT NOT NULL DEFAULT 0,
    `response_count` INT(11) NOT NULL DEFAULT 0,
    `average_response_time` INT(11) NOT NULL DEFAULT 0,
    `last_active` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_staff` (`staff_identifier`),
    KEY `idx_tickets_closed` (`tickets_closed`),
    KEY `idx_average_rating` (`average_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rx_staff_chat` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `sender_identifier` VARCHAR(50) NOT NULL,
    `sender_name` VARCHAR(100) NOT NULL,
    `message` TEXT NOT NULL,
    `is_broadcast` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_sender` (`sender_identifier`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create a view for active tickets
CREATE OR REPLACE VIEW `rx_active_tickets` AS
SELECT 
    t.*,
    COUNT(m.id) as message_count,
    MAX(m.created_at) as last_message_at
FROM `rx_tickets` t
LEFT JOIN `rx_ticket_messages` m ON t.id = m.ticket_id
WHERE t.status != 'closed'
GROUP BY t.id;

-- Create a view for staff performance
CREATE OR REPLACE VIEW `rx_staff_performance` AS
SELECT 
    s.*,
    COUNT(DISTINCT t.id) as active_tickets
FROM `rx_staff_stats` s
LEFT JOIN `rx_tickets` t ON s.staff_identifier = t.claimed_by AND t.status != 'closed'
GROUP BY s.id
ORDER BY s.tickets_closed DESC;