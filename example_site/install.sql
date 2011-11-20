# To install, simply run: mysql < install.sql

CREATE DATABASE `orderby_injection` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE `orderby_injection`.`user` (
`id` INTEGER( 11 ) NOT NULL AUTO_INCREMENT ,
`username` VARCHAR( 15 ) NOT NULL ,
PRIMARY KEY (id)
) ENGINE = MYISAM ;

INSERT INTO `orderby_injection`.`user` (
`username`
)
VALUES (
'admin'
), (
'ahfy'
), (
'guest'
), (
'eMole'
), (
'html'
), (
'moderator'
), (
'test'
);
