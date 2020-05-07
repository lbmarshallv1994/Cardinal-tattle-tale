use strict;
use warnings;
use Template;
use DBI;
use Net::OpenSSH;
use Data::Dumper;
use Config::Tiny;
use File::Spec;
use File::Copy;
use File::Basename;
use File::Path;


my $config = Config::Tiny->read( "tattler.ini", 'utf8' );
#ssh host
my $total_time_start = time();

#database name
my $db = $config->{PSQL}{db};
#database hostname
my $host = $config->{PSQL}{host};
#database port
my $port = $config->{PSQL}{port};
my $ssh_db_port = $config->{SSH}{db_port};
my $key_name = $config->{SSH}{keyname};
my $ssh_host = $config->{SSH}{host};
my $ssh;
#set up SSH tunnel
if( $config->{SSH}{enabled} eq 'true'){
    $ssh = Net::OpenSSH->new($ssh_host,key_path => $key_name, master_opts => [-L => "127.0.0.1:$port:localhost:$ssh_db_port"]) or die;
}
my $dsn = "dbi:Pg:dbname='$db';host='$host';port='$port';";
#database username
my $usr = $config->{PSQL}{username};
# database password
my $pwrd = $config->{PSQL}{password};
# folders to output web content
my $output_folder = $config->{FOLDERS}{output};
# script will run every report in this folder
my $sqldir = $config->{FOLDERS}{reports};
# script will create table using SQL files in this folder
# copy ids in this table will be ignored
my $ignoredir = $config->{FOLDERS}{ignore};
my $ignorephp = $config->{FOLDERS}{php};
my $ignorephpdirname = $config->{FOLDERS}{script};
my $ignorephpdir = $output_folder."/".$ignorephpdirname;
my $ignorephpabs =  $ignorephpdir."/".$ignorephp;
my $ignorephpurl =  "../".$ignorephpdirname."/".$ignorephp;
# how many rows to return per report
my $limit =  $config->{PSQL}{limit};
my $copy_url =  $config->{EVERGREEN}{copy_url};
my $bib_url = $config->{EVERGREEN}{bib_url};
my $patron_url = $config->{EVERGREEN}{patron_url};
my $dbh =DBI->connect($dsn, $usr, $pwrd, {AutoCommit => 0}) or die ( "Couldn't connect to database: " . DBI->errstr );

my $ignore_table_statement = "CREATE TEMP TABLE tattler_ignore_list(report_name VARCHAR,system_id BIGINT, copy_id BIGINT);\n";
if(-d $ignoredir){
    my @ignore_files = glob $ignoredir."/*.sql";
    # iterate over all SQl scripts in the ignore list directory
    foreach my $sql_file (@ignore_files) {
        open my $fh, '<', $sql_file or die "Can't open file $!";
        $ignore_table_statement .= do { local $/; <$fh> };
    }

}
else{
    print("Ignore list not found, creating directory.\n");
    mkdir $ignoredir;
    
}

# create directory to put script in, it must be hosted along with the web files.
unless(-d $ignorephpdir){
     print("Ignore script not found at $ignorephpdir, creating directory.\n");
    mkdir $ignorephpdir;
    my $tt = Template->new({
        INTERPOLATE  => 1
        }) || die "$Template::ERROR\n"; 
    my $result = {};
    $result->{ignore_table} = "tattler_ignore_list";
    $result->{output_dir} = File::Spec->rel2abs($ignoredir);
    $tt->process($ignorephp.".tt2", $result,$ignorephpabs)
    || die $tt->error(), "\n";
}

# relation needs to be created even if it's empty 
my $ign_st = $dbh->prepare($ignore_table_statement);
print("Creating ignore table\n");
$ign_st->execute();
# get org unit name and shortnames
my $org_st = $dbh->prepare("select * from actor.org_unit");
my %org_name; 
my %org_shortname; 
print("Retrieving org unit data\n");
$org_st->execute();
for((0..$org_st->rows-1)){
    my $sql_hash_ref = $org_st->fetchrow_hashref;
    $org_name{$sql_hash_ref->{'id'}} = $sql_hash_ref->{'name'}; 
    $org_shortname{$sql_hash_ref->{'id'}} = $sql_hash_ref->{'shortname'}; 
    # remove directory if it exists so we will have fresh results
    my $sys_dir = "$output_folder/$sql_hash_ref->{'shortname'}";
    if(-d $sys_dir){
        print("removing $sys_dir\n");
        rmtree($sys_dir);
    }
}
$org_st->finish();

my @files = glob $sqldir."/*.sql";
# iterate over all SQl scripts in the sql directory
foreach my $sql_file (@files) {
    my ($report_title,$dir,$ext) = fileparse($sql_file,'\..*');
    my $nice_report_title = "$report_title";
    # report title is the file name with the extension removed and dashes turned to spaces
    $nice_report_title =~ s/-/ /g;;

    print "running " . $report_title . "\n";
    open my $fh, '<', $sql_file or die "Can't open file $!";
    my $statement_body = do { local $/; <$fh> };

    # prepare statement
    my $sth = $dbh->prepare($statement_body);
    my $start_time = time();
    # the first bind variable is the name of the report, it is used with the ignore table
    # the second bind variable is the number of rows to return per system
    $sth->execute($report_title,$limit);   
    my $header_ref = $sth->{NAME_lc};
    my @headers = @$header_ref;
    my $data_ref = $sth->fetchall_arrayref();
    my @data = @$data_ref;
    my ($sys_id_index) = grep { $headers[$_] eq 'system_id' } (0 .. (scalar @headers)-1);
    my ($bib_id_index) = grep { $headers[$_] eq 'bib_id' } (0 .. (scalar @headers)-1);
    my ($copy_id_index) = grep { $headers[$_] eq 'copy_id' } (0 .. (scalar @headers)-1);
    my ($circ_lib_index) = grep { $headers[$_] eq 'circ_lib' } (0 .. (scalar @headers)-1);
    #print Dumper($data);
    $sth->finish;
    my $current_system = 0;
    my $current_count = 1;
    my $current_file;
     my $l = $#data + 1;
     my $complete_time = (time() - $start_time)/60.0;
     print("retrieved $l rows in $complete_time minutes\n");
     # for each row returned
    for(my $i = 0; $i < $l; $i++){
        my $sql_row_ref = $data[$i];
        my @sql_row = @$sql_row_ref;
       # print Dumper(@sql_row);
        # set up file if this is new system
        if($sql_row[$sys_id_index] != $current_system){
            # set new current system
            $current_system = $sql_row[$sys_id_index];
            $current_count = 1;
      
            # end previous file
            if(defined $current_file){
                print $current_file "</tbody></tr></table>";
                print $current_file "</form>";
                print $current_file "</html>";
                close $current_file;
            }
            my $sys_dir = "$output_folder/$org_shortname{$current_system}";
            mkdir $sys_dir unless -d $sys_dir;
            my $file = $sys_dir."/".$report_title.".html";

            # create the file.
            unless(open $current_file, '>'.$file) {
                die "\nUnable to create $file\n";
            }

            # init file
            print $current_file "<html> <style> body{font-family: arial;} .tt-table{border-collapse:collapse;} .tt-table td{padding-left: 15px; padding-top: 5px; padding-bottom: 5px; padding-right: 15px;} .tt-table thead tr{color: rgb(100, 100, 100); background-color:rgb(225, 225, 225);border-bottom-style: solid; border-bottom-width: 1.5px; border-bottom-color:rgb(200, 200, 200);  border-collapse: collapse; font-weight: bold;} .tt-table tbody td:nth-child(1){color: rgb(100, 100, 100); background-color:rgb(225, 225, 225);border-right-style: solid; border-right-width: 1.5px; border-right-color:rgb(200, 200, 200);  border-collapse: collapse; font-weight: bold;border-bottom-color:rgb(128, 200, 200) !important;} .tt-table tbody tr { border-bottom-style: solid; border-bottom-width: 1px; border-bottom-color:rgb(221, 221, 221);  border-collapse: collapse;} .tt-table tbody tr:nth-child(odd){background-color:rgb(245, 245, 245);}  </style>";
            print $current_file "<h1>$org_name{$current_system}</h1>";
            print $current_file "<h2>$nice_report_title</h2>";
            print $current_file "<a href=\"index.html\">Return to index</a>";
            print $current_file "<hr/>";
            print $current_file "<form action=\"$ignorephpurl\" method=\"POST\" id=\"ignoreForm\">";
            print $current_file "<input type=\"hidden\" id=\"reportName\" name=\"reportName\" value=\"$report_title\">";
            print $current_file "<input type=\"hidden\" id=\"systemID\" name=\"systemID\" value=\"$current_system\">";
            print $current_file "<input type=\"submit\">";
            print $current_file "<table class=\"tt-table\">";
            print $current_file "<thead><tr>";
            print $current_file "<td>#</td>";
            print $current_file "<td>Ignore</td>";
            # init headers from data in table
            for (@headers){
                print $current_file "<td>$_</td>";
            }
            print $current_file "</tr></thead>";
            print $current_file "<tbody>";
        }
        # send staff to the right subdomain for their system
        my $subdomain ="https://";
        $subdomain .= $org_shortname{$current_system}.".";
        my $copy_id = $sql_row[$copy_id_index];
        print $current_file "<tr>";
        print $current_file "<td>$current_count</td>";
        print $current_file "<td><input type=\"checkbox\" name=\"copyID[]\" value=\"$copy_id\"></td>";
        while (my ($index, $elem) = each @sql_row) {
            if(defined($elem)){
                if ($headers[$index] =~ m/email/ ) {
                    print $current_file "<td><a href=\"mailto:$elem\">$elem</a></td>";
                }
                elsif ($headers[$index] =~ m/bib_id/ ) {
                    print $current_file "<td><a href=\"$subdomain$bib_url$elem\">$elem</a></td>";
                }
                elsif ($headers[$index] =~ m/copy_id/ ) {
                    print $current_file "<td><a href=\"$subdomain$copy_url$elem\">$elem</a></td>";
                }
                elsif ($headers[$index] =~ m/creator_id/ ) {
                    print $current_file "<td><a href=\"$subdomain$patron_url$elem/checkout\">$elem</a></td>";
                }
                elsif ($headers[$index] =~ m/editor_id/ ) {
                    print $current_file "<td><a href=\"$subdomain$patron_url$elem/checkout\">$elem</a></td>";
                }
                elsif ($headers[$index] =~ m/deletor_id/ ) {
                    print $current_file "<td><a href=\"$subdomain$patron_url$elem/checkout\">$elem</a></td>";
                }
                else{              
                    print $current_file "<td>$elem</td>";
                }
            }
            else{
                print $current_file "<td></td>";
            }
        }
        print $current_file "</tr>";
        
        $current_count += 1;   
    }
    # end last file
    if(defined $current_file){
        print $current_file "</tbody></tr></table>";
        print $current_file "</form>";
        print $current_file "</html>";
        close $current_file;
    }
}

my $index_data = "<html><body><ul>";
foreach my $current_system (keys %org_shortname){
my $current_folder = "$output_folder/$org_shortname{$current_system}";
if(-d $current_folder){
        $index_data .= "<li><a href=\"/$org_shortname{$current_system}\">$org_shortname{$current_system}</a></li>";
		my @report_files;
		opendir(DIR, $current_folder) or die $!;
		
		while (my $file = readdir(DIR)) 
		{
        next unless (-f "$current_folder/$file");
			# Use a regular expression to find files ending in .html
			next if (lc$file =~ m/index/);
			next unless (lc$file =~ m/\.html$/);
			push(@report_files,$file);
		}
		closedir(DIR);
    
    my $index_file;
    my $index_file_name = $current_folder."/index.html";
       unless(open $index_file, '>'.$index_file_name) {
                die "\nUnable to create $index_file_name\n";
            }
		print $index_file "<html>";
		print $index_file "<style> body{font-family: arial;}</style>";
		print $index_file "<h1>$org_name{$current_system}</h1>";
        print $index_file "<a href=\"../index.html\">Return to index</a>";
        print $index_file "<hr/>\n";
        print $index_file "<ul>\n";
        foreach(@report_files)
		{
			my $file = $_;
            my @s1 = split(/\./,$file);
			my @s2 = split(/-/,$s1[0]);
            my $nice_report_title = join(" ",@s2);
			
			 print $index_file "<li><a href=\"$file\">$nice_report_title</a></li>\n";
		}
        
		 print $index_file "</ul>\n";
         print $index_file "</html>";
         close $index_file;
}
}
$index_data .= "</ul></body></html>";
my $index_file;
my $index_file_name = $output_folder."/index.html";
unless(open $index_file, '>'.$index_file_name) {
        die "\nUnable to create $index_file_name\n";
    }
print $index_file $index_data;  
close $index_file;           
$dbh->disconnect;
     my $complete_time = (time() - $total_time_start)/60.0;
     print("script finished in $complete_time minutes\n");
     
