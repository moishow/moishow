ALTER TABLE app_user ADD COLUMN interests_json text NOT NULL DEFAULT '[]';
ALTER TABLE app_user ADD COLUMN bio varchar(300) NOT NULL DEFAULT '';
ALTER TABLE app_user ADD COLUMN avatar_file_id uuid REFERENCES private_file(id);
