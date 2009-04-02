=head1 NAME

MQdb::MappedQuery - DESCRIPTION of Object

=head1 SYNOPSIS

Yet another ORM based design pattern.  This is an evolution of several
ideas I have either used or created over the last 15 years of coding.  
A variation on the ActiveRecord design pattern that trades more 
flexibility, power and control for slightly less automation.  
Still provides a development speed/ease advange over most ORM patterns.

=head1 DESCRIPTION

MappedQuery is an abstract superclass that is a variation on the
ActiveRecord design pattern.  Instead of actively mapping
a table into an object, this will actively map the result of
a query into an object.  The query is standardized for a subclass
of this object, and the columns returned by the query define
the attributes of the object.  This gives much more flexibility 
than the standard implementation of ActiveRecord.  Since this
design pattern is based around mapping a query (from potentially a
multiple table join) to a single class object, this pattern is
called MappedQuery.

In this particular implementation of this design pattern
(mainly due to some limitations in perl) several aspects
must be hand coded as part of the implementation of a 
subclass.  Subclasses must handcode
- all accessor methods
- override the mapRow method 
- APIs for all explicit fetch methods 
  (by using the superclass fetch_single and fetch_multiple)
- the store methods are coded by general DBI code (no framework assistance)

Individual MQdb::Database handle objects are assigned at an instance level
for each object. This is different from some ActiveRecord implementations 
which place database handles into a global context or at the Class level.
By placing it with each instance, this allows creation of instances of the
same class pulled from two different databases, but with similar schemas.
This is very useful when building certain types of data analysis systems.

The only restriction is that the database handle must be able run the 
queries that the object requires for it to work.

Future implementations could do more automatic code generation
but this version already speeds development time by 2x-3x
without imposing any limitations and retains all the flexibility
of handcoding with DBI.

=head1 CONTACT

Jessica Severin <jessica.severin@gmail.com>

=head1 LICENSE

* Software License Agreement (BSD License)
* MappedQueryDB [MQdb] toolkit
* copyright (c) 2006-2009 Jessica Severin
* All rights reserved.
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of Jessica Severin nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDERS BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package MQdb::MappedQuery;

use strict;
use MQdb::Database;
use MQdb::DBStream;

use MQdb::DBObject;
our @ISA = qw(MQdb::DBObject);

#################################################
# Factory methods
#################################################

#################################################
# Instance methods
#################################################

#################################################
# Framework database methods 
# fetch methods are class level
# insert/update/delete are instance level
#################################################

=head2 fetch_single

  Arg (1)    : $database (MQdb::Database)
  Arg (2)    : $sql (string of SQL statement with place holders)
  Arg (3...) : optional parameters to map to the placehodlers within the SQL
  Example    : $obj = $self->fetch_single($db, "select * from my_table where id=?", $id);
  Description: General purpose template method for fetching a single instance
               of this class(subclass) using the mapRow method to convert
               a row of data into an object.
  Returntype : instance of this Class (subclass)
  Exceptions : none
  Caller     : subclasses (not public methods)

=cut

sub fetch_single {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($db);
  my $dbc = $db->get_connection;
  my $sth = $dbc->prepare($sql, { ora_auto_lob => 0 });
  $sth->execute(@params);
  
  my $obj = undef;
  my $row_hash = $sth->fetchrow_hashref;
  if($row_hash) {
    $obj = $class->new();
    $obj->database($db);
    $obj = $obj->mapRow($row_hash, $dbc);  #required by subclass
  }
  
  $sth->finish;
  return $obj;
}


=head2 fetch_multiple

  Arg (1)    : $database (MQdb::Database)
  Arg (2)    : $sql (string of SQL statement with place holders)
  Arg (3...) : optional parameters to map to the placehodlers within the SQL
  Example    : $obj = $self->fetch_single($db, "select * from my_table where id=?", $id);
  Description: General purpose template method for fetching an array of instance
               of this class(subclass) using the mapRow method to convert
               a row of data into an object.
  Returntype : array of instance of this Class (subclass)
  Exceptions : none
  Caller     : subclasses (not public methods)

=cut

sub fetch_multiple {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($db);
  my $obj_list = [];
  
  my $dbc = $db->get_connection;  
  my $sth = $dbc->prepare($sql, { ora_auto_lob => 0 });
  eval { $sth->execute(@params); };
  if($@) {
    printf("ERROR with query: %s\n", $sql);
    printf("          params: ");
    foreach my $param (@params) {
      print("'%s'  ", $param);
    }
    print("\n");
    die;
  }

  while(my $row_hash = $sth->fetchrow_hashref) {

    my $obj = $class->new();
    $obj->database($db);
    $obj = $obj->mapRow($row_hash, $dbc);  #required by subclass

    push @$obj_list, $obj;
  }
  $sth->finish;
  return $obj_list;
}


=head2 old_stream_multiple

  Arg (1)    : $database (MQdb::Database)
  Arg (2)    : $sql (string of SQL statement with place holders)
  Arg (3...) : optional parameters to map to the placehodlers within the SQL
  Example    : $obj = $self->fetch_single($db, "select * from my_table where id=?", $id);
  Description: General purpose template method for fetching an array of instance
               of this class(subclass) using the mapRow method to convert
               a row of data into an object.
  Returntype : array of instance of this Class (subclass)
  Exceptions : none
  Caller     : subclasses (not public methods)

=cut

sub old_stream_multiple {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($db);
  my $obj_list = [];
  
  my $dbc = $db->get_connection;  
  my $sth = $dbc->prepare($sql, { "mysql_use_result" => 1 });
  $sth->execute(@params);
  return $sth;
}

sub next_in_stream {
  my $class = shift;
  my $sth = shift;

  if(my $row_hash = $sth->fetchrow_hashref) {

    my $obj = $class->new();
    $obj->mapRow($row_hash);  #required by subclass

    return $obj;
  }
  $sth->finish;
  return undef;
}


=head2 stream_multiple

  Arg (1)    : $database (MQdb::Database)
  Arg (2)    : $sql (string of SQL statement with place holders)
  Arg (3...) : optional parameters to map to the placehodlers within the SQL
  Example    : $obj = $self->fetch_single($db, "select * from my_table where id=?", $id);
  Description: General purpose template method for fetching an array of instance
               of this class(subclass) using the mapRow method to convert
               a row of data into an object.
  Returntype : DBStream object
  Exceptions : none
  Caller     : subclasses (not public methods)

=cut

sub stream_multiple {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($db);
  
  my $stream = new MQdb::DBStream(db=>$db, class=>$class);
  $stream->prepare($sql, @params);
  return $stream;
}


=head2 fetch_col_value

  Arg (1)    : $sql (string of SQL statement with place holders)
  Arg (2...) : optional parameters to map to the placehodlers within the SQL
  Example    : $value = $self->fetch_col_value($db, "select some_column from my_table where id=?", $id);
  Description: General purpose function to allow fetching of a single column from a single row.
  Returntype : scalar value
  Exceptions : none
  Caller     : within subclasses to easy development

=cut

sub fetch_col_value {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($db);
  my $dbc = $db->get_connection;
  my $sth = $dbc->prepare($sql);
  $sth->execute(@params);
  my ($value) = $sth->fetchrow_array();
  $sth->finish;
  return $value;
}


=head2 fetch_col_array

  Arg (1)    : $sql (string of SQL statement with place holders)
  Arg (2...) : optional parameters to map to the placehodlers within the SQL
  Example    : $array_ref = $self->fetch_col_array($db, "select some_column from my_table where source_id=?", $id);
  Description: General purpose function to allow fetching of a single column from many rows.
  Returntype : array reference of scalar values
  Exceptions : none
  Caller     : within subclasses to easy development

=cut

sub fetch_col_array {
  my $class = shift;
  my $db = shift;
  my $sql = shift;
  my @params = @_;

  my @col_array=();
  
  die("no database defined\n") unless($db);
  my $dbc = $db->get_connection;
  my $sth = $dbc->prepare($sql);
  $sth->execute(@params);
  
  while(my ($value) = $sth->fetchrow_array()) {
    push @col_array, $value;
  }
  $sth->finish;
  return \@col_array;
}


sub test_exists {
  my $self = shift;
  my $sql = shift;
  my @params = @_;

  die("no database defined\n") unless($self->database);
  my $dbc = $self->database->get_connection;
  my $sth = $dbc->prepare($sql);
  $sth->execute(@params);
  my $exists=0;
  if(my $row_hash = $sth->fetchrow_hashref) { $exists=1; }
  $sth->finish;
  return $exists;
}

#################################################
# Subclass must override these methods
#################################################
sub mapRow {
  my $self = shift;
  my $row_hash = shift;
  my $dbh = shift; #optional 
  
  die("mapRow must be implemented by subclasses");
  #should by implemented by subclass to map columns into instance variables

  return $self;
}

sub store {
  my $self = shift;
  die("store must be implemented by subclass");
}


#################################################
#
# internal methods
#
#################################################

sub next_sequence_id {
  my $self = shift;
  my $sequenceName = shift;
  
  my $dbh = $self->database->get_connection;
  
  my $sql = 'select '. $sequenceName . '.nextval from sys.dual';  
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  my ($dbID) = $sth->fetchrow_array();
  $sth->finish;
  #printf("incremented sequence $sequenceName id:%d\n", $dbID);
  
  return $dbID;
}




1;





