//- To see all users,hosts, and passwords
SELECT User, Host, Password FROM mysql.user;
SELECT user FROM mysql.user GROUP BY user;

//- To change a user password
SET PASSWORD FOR '{{root}}'@'{{localhost}}'= PASSWORD('{{THEPASSWORD}}');
SET PASSWORD FOR '{{root}}'@'{{127.0.0.1}}'= PASSWORD('{{THEPASSWORD}}');
SET PASSWORD FOR '{{root}}'@'::1' = PASSWORD('{{THEPASSWORD}}');

//- Make new mysql user
USE {{database you want to into}} ; //maybe not?
GRANT ALL PRIVILEGES ON *.* TO '{{username}}'@'{{localhost}}' IDENTIFIED BY 'password';

//- Grant only Select permission to user
GRANT SELECT ON *.* TO '{{username}}'@'{{localhost}}';

//- Create a database
CREATE DATABASE {{dbname}};

//- Create a table and insert data into it
CREATE TABLE {{tablename}} ( id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id) );
INSERT INTO {{tablename}} ( id, name ) VALUES ( null, 'Sample data' );

//- Delete a table by name
DROP TABLE {{tablename}};

//- Delete database
DROP DATABASE {{dbname}};

//- Delete User
DELETE FROM mysql.user WHERE user = '{{username}}';
