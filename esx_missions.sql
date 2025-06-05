CREATE TABLE `user_missions` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`identifier` VARCHAR(60) NOT NULL COLLATE 'utf8mb4_general_ci',
	`mission_data` LONGTEXT NOT NULL COLLATE 'utf8mb4_bin',
	`last_updated` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
	PRIMARY KEY (`id`) USING BTREE,
	UNIQUE INDEX `identifier` (`identifier`) USING BTREE,
	INDEX `mission_name` (`mission_data`(768)) USING BTREE,
	CONSTRAINT `mission_data` CHECK (json_valid(`mission_data`))
)
COLLATE='utf8mb4_general_ci'
ENGINE=InnoDB
;
