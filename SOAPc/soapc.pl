#!/usr/bin/perl
#
#    This file is part of SIBBIE.
#
#    SIBBIE is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    SIBBIE is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SIBBIE.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
#use strict;
use threads;

use Socket::Class;
use Socket qw(:DEFAULT :crlf SOMAXCONN);
use DBI;
require ".auth.pl";

sub is_allowed_ip {
   if ($_[0] eq "129.21.50.68" || $_[0] eq "127.0.0.1") {
      return 1;
   } else {
      return 0;
   }
}

$soapc = Socket::Class->new( 'local_port' => '7628',
                             'local_addr' => "129.21.50.34",
                             'listen'     => SOMAXCONN) or die Socket::Class->error;


while ($client = $soapc->accept()) {
   print "Connection recieved";
   if (is_allowed_ip($client->remote_addr)) {
      my @data;
      $data[1] = $client->readline;
      $data[2] = $client->readline;
      $data[3] = $client->readline;
      $client->write("? ");
      print "Got $data[1] \nGot $data[2] \nGot $data[3] \n";
      print "Got connection from " . $client->remote_addr . "\n";
      threads->create('setupStream',$data[1],$data[2],$data[3]);
      print $client->remote_addr . " made a successful call\n";
   } else {
      print $client->remote_addr . " was not an allowed host\n";
   }
   $client->free;
}

sub setupStream {
   my $user = find_user($_[2]);
   my @host = find_host($user);
   if ($host[2] eq "1") {
      tell_soapd($host[0],"start");
      system("sleep 3");
      play($_[0],"The $_[1]","http://$host[0]:$host[1]");
   } else {
      play($_[0],"The $_[1]","$host[0]");
   }
}

sub find_user {
   my $ibutton = $_[0] or die "No iButton ID specified";
   my $addr = "drink.csh.rit.edu";
   my $port = 4242;

   my $sunday = Socket::Class->new( 'remote_addr' => $addr,
                                    'remote_port' => $port)
                                  or die Socket::Class->error;

   $sunday->writeline("IBUTTON " . $ibutton);
   $sunday->writeline("WHOAMI");
   if ($sunday->readline ne "OK Welcome to Big Drink") {
      die("Big Drink did not respond");
   }
   $sunday->readline;
   my $user = $sunday->readline;
   if (substr($user,0,2) ne "OK") {
      die("Big Drink did not respond with 'OK'");
   }
   $user = substr($user,13);
   print "\nUser: $user\n";
   $sunday->writeline("");
   $sunday->close;

   return $user;
}

sub find_host {
   my $user = $_[0] or die "No username specified";
   my $dbpass = our $mpw;

   my $soap_db = DBI->connect('dbi:mysql:database=soapc;host=db.csh.rit.edu;port=3306',"soapc",$dbpass);
   my @hosts = $soap_db->selectrow_array("SELECT host,port,soapd FROM soap_config WHERE username=\"$user\"");
   return @hosts;
}

sub tell_soapd {
   my $addr = $_[0] or die("Address not specified");
   my $cmd = $_[1] or die("Command not specified");
   
   my $soapc = Socket::Class->new( 'remote_addr' => $addr,
                                   'remote_port' => 7626)
                or die Socket::Class->error;
   $soapc->readline;
   $soapc->write($cmd . $CRLF);
   $soapc->close;
}

use XML::RPC;

sub play {
   my $soap;
   my $r;
   if ($_[0] eq 'n') {
      $soap = XML::RPC->new('http://localhost:1235/RPC2');
   } elsif ($_[0] eq "s") {
      $soap = XML::RPC->new('http://soap-south:1235/RPC2');
   }

   if ($_[1] eq "The Vator" || $_[1] eq "The L" || $_[1] eq "The Stairs") {
      $r = $soap->call('playStream',$_[1],$_[2]);
   }
}
