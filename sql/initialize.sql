-- sql/initialize.sql
-- Initializes the database.
--
-- Author: Nathan Campos <nathan@innoveworkshop.com>

-- Create users table.
CREATE TABLE IF NOT EXISTS Users(
	id         INTEGER PRIMARY KEY,
	email      TEXT    NOT NULL UNIQUE,
	password   TEXT    NOT NULL,
	permission INTEGER NOT NULL
);

-- Create categories table.
CREATE TABLE Categories(
	id     INTEGER PRIMARY KEY,
	name   TEXT    UNIQUE
);
