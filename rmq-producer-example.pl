#!/usr/bin/perl

# this is an example that demonstrate how to post messages to RabbitMQ using our rmq.pm wrapper module (
# we connect to rmq, creates exchange "liberator", than creates two queues, post message into the queue and exit
# you can see connetion and the message using rmq web console: http://localhost:15672/#/queues/%2F/client.firstConnect

use strict;
use warnings;
no warnings qw(once);
use utf8;
use open (':encoding(utf8)', ':std');
use AE;
use Data::Dumper;

use lib ".";
use lib "./lib";
use lib "../lib";

use logtiny;
use rmq;

$rmq::exchange_name = "liberator";

$rmq::host = 'localhost';
$rmq::port = 5672;
$rmq::user = 'test';
$rmq::pass = 'test';

$rmq::queues = {
    "client.firstConnect" => {

    },
    "client.someSecondQueue" => {

    }
};

my $loop = AE::cv;

my $connected = AE::cv (
    sub {
        # test data
        my $data = { region => "EU", sn => "69980c30429e4831" };
        my $id = rmq::publish("client.firstConnect", $data);
        logwi("Message $id was sent with payload: " . Dumper($data));
        # finish main loop
        $loop->send;
    }
);

my $rmq = rmq::connect($connected);

=pod

my $scheduler = AnyEvent->timer (
    after => 1,
    interval => 5,
    cb => sub {
        #logwi("tick\n");
        if (defined $rmq::rmq_channel) {
            my $data = { key => "test_data"};
            my $id = rmq::publish("client.firstConnect", $data);
            logwi("Message $id was sent with payload: " . Dumper($data));
        }
    }
);

=cut


$loop->recv;
