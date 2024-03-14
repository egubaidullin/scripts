# MySQL Database Creation and Privilege Management Script
This Bash script simplifies the process of creating MySQL databases and granting privileges to the webmaster user. It provides the following features:

## Features
**Configuration File Support**: The script can read the MySQL user and password from a configuration file (default: config.ini). If the configuration file is not provided or the variables are not defined, the script uses default values.

**Database Existence Check:** Before creating a new database, the script checks if the database already exists and skips it if it does.

**Privilege Granting:** The script prompts the user to enter the desired privileges for the webmaster user, allowing for more flexibility in granting permissions.

**Error Handling and Usage Display:** The script includes robust error handling and displays the usage information if the script is called without the required arguments.

## Usage
Save the script to a file, e.g., create_databases.sh.

Make the script executable: chmod +x create_databases.sh.

(Optional) Create a configuration file (e.g., config.ini) with the following content:

```
MYSQL_USER=myuser
MYSQL_PASS=mypassword
```
Run the script with the database names as arguments:

```
./create_databases.sh mydb1 mydb2 mydb3
```
or with the configuration file option:

```
./create_databases.sh -c config.ini mydb1 mydb2 mydb3
```
The script will prompt you to enter the desired privileges for the webmaster user, and then create the specified databases and grant the necessary permissions.

## Usage Options
-c <config_file>: Specify the configuration file to use (default: config.ini).
<database1> [database2] [database3] ...: The names of the databases to create.
## Example
```
./create_databases.sh -c config.ini mydb1 mydb2 mydb3
```
This will create the databases mydb1, mydb2, and mydb3, using the MySQL user and password from the config.ini file, and grant the necessary privileges to the webmaster user.
