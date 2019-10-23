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

-- Create the inventory table.
CREATE TABLE Inventory(
	id          INTEGER PRIMARY KEY,
	quantity    INTEGER NOT NULL,
	mpn         TEXT    NOT NULL UNIQUE,
	cat_id      INTEGER DEFAULT NULL,
	image_id    INTEGER DEFAULT NULL,
	description TEXT,
	parameters  TEXT,

	FOREIGN KEY (cat_id)
		REFERENCES Categories(id) ON DELETE SET NULL,
	FOREIGN KEY (image_id)
		REFERENCES Images(id) ON DELETE SET NULL
);

-- Create the images table.
CREATE TABLE Images(
	id   INTEGER PRIMARY KEY,
	name TEXT    NOT NULL,
	path TEXT    NOT NULL
);

-- Create the inventory query view.
CREATE VIEW v_Inventory AS
SELECT
	id,
	quantity,
	mpn,
	cat_id,
	Categories.name AS category,
	image_id,
	Images.name AS image_name,
	Images.path AS image_path,
	description,
	parameters
FROM
	Inventory
	INNER JOIN Categories ON Categories.id = Inventory.cat_id
	INNER JOIN Images ON Images.id = Inventory.image_id;
