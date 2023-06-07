#!/usr/bin/perl

# this is an example that demonstrate how to get messages from RabbitMQ using our rmq.pm wrapper module (
# we connect to rmq, creates exchange "liberator", than creates two queues, post message into the queue and exit
# you can observe connections, queues and the messages using rmq web console: http://localhost:15672/#/queues/%2F/client.firstConnect

use strict;
use warnings;
no warnings qw(once);
use utf8;
use open (':encoding(utf8)', ':std');
use AE;
use Data::Dumper;

use lib ".";
use lib "./lib";

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
};

my $loop = AE::cv;

my $connected = AE::cv (
    sub {
        my $id = rmq::consume("client.firstConnect", sub {
            my $msg = shift;
            logwi("Message received: " . Dumper($msg->{body}));
        });
    }
);

my $rmq = rmq::connect($connected);

$loop->recv;
