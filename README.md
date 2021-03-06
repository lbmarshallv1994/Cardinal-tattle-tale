# Cardinal-tattle-tale
Create interactive reports for copies or bib records that do not follow the cataloging best practices. Output is an interactive webpage for each provided SQL file. Results are broken down per system. Users can mark records to ignore the next time that the script is run. These marked records are entered into SQL files that the script takes in to make a virtual "ignore list" table.  

## Installation
Create the folder for your webpages to be output into, make sure the folder you create has write permissions enabled for the user that runs the script.  

Create the folder for your ignore list to be output into, make sure this folder has write permissions for other users.
Create your tattler.ini using the provided tattler.example.ini file. 

## Configuration

### SSH
* **enabled:** Enable SSH Tunneling 
* **host:** The SSH host, ex) user@host:port
* **keyname:** the private key for this SSH host
* **db_port:** The port that will be tunneled through. For most use-cases this will be the same as your PSQL port. 

### PSQL
* **db:** the name of your Evergreen database
* **host:** the host IP of your Evergreen database, if tunneling is enabled this will most likely be 127.0.0.1
* **port:** The port to connect to PSQL through
* **username:** the user to execute PSQL operations as
* **password:** the password of the user to connect to PSQL
* **limit:** The maximum number of rows to return **per system**.

### FOLDERS
* **output:** Where to output web pages generated by the script
* **reports:** location of SQL files for generating web pages
* **ignore:** location of your ignore list sql files
* **php:** name of the form action PHP script that will generate ignore list SQL files. Extension should be PHP. Script will be generated using .tt2 file of the same name

### EVERGREEN
* **copy_url:** base URL to create links to items
* **bib_url:** base URL to create links to bib records
* **patron_url:** base URL to create links to patrons

## Prerequisites
### Perl 
* **recommended version:** 5.28
#### Modules
Use CPAN to install these modules.
* **Template:** Used for creating the PHP form action from a supplied *.php.tt2* file
* **DBI:** Creates a connection to a PSQL database
* **Net::OpenSSH:** Creates an SSH tunnel to connect to a remote database
* **Config::Tiny:** reads in your *tattler.ini* file 
* **File::Spec:** Translates relative paths into absolute paths when generating the PHP script
* **File::Basename:** Parses the report name out of your SQL files

### PHP-FPM
* **recommended version:** 7.3.17
Handles PHP sent to your webserver. We're using a PHP script to update our database given user input.

#### NGINX Configuration
`
    location ~ \.php$ {  
        include /etc/nginx/fastcgi_params;  
        fastcgi_pass  127.0.0.1:9000;  
        fastcgi_index index.php;  
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;  
    }  
`



