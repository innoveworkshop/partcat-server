-- sql/initialize.sql
-- Initializes the database.
--
-- Author: Nathan Campos <nathan@innoveworkshop.com>

CREATE TABLE IF NOT EXISTS Users(
	id         INTEGER PRIMARY KEY,
	email      TEXT    NOT NULL UNIQUE,
	password   TEXT    NOT NULL UNIQUE,
	permission INTEGER NOT NULL
);
