#
# RabbitMQ communication wrapping module, that uses AnyEvent::RabbitMQ module for RabbitMQ interaction
# see example rmq-producer-example.pl and rmq-consumer-test.pl
#
# (c) Starshiptroopers, Aleksander Cherviakov

package rmq;
use strict;
use warnings FATAL => 'all';

use Exporter;
our @ISA = ("Exporter");
our @EXPORT = qw(connect create_queue publish);
use utf8;
use AnyEvent;
use AE;
use AnyEvent::RabbitMQ;
use JSON::XS;
use open (":encoding(utf8)", ":std");

use lib ".";
use lib "./lib";
use lib "../lib";
use logtiny;
use Data::Dumper;

our $rmq = undef;
our $rmq_channel = undef;
our $exchange_name = "test";

our $host = undef;
our $port = undef;
our $user = undef;
our $pass = undef;

our $queues = undef;

my $rmq_reconnect_task = undef;

my $log_prefix = "RMQ";
my @id_chars = ("A" .. "F", 0..9);

sub connect($) {
    my $connectedEvent = shift;
    if (defined $rmq_channel) {
        return
    }

    undef $rmq;
    $rmq = rmq_connect($connectedEvent);
    if (defined $rmq_reconnect_task) {
        undef $rmq_reconnect_task
    }
    $rmq_reconnect_task = AnyEvent->timer (
        after => 5,
        interval => 10,
        cb => sub {
            if (! defined $rmq_channel) {
                logwi("$log_prefix: reconnecting is initiated");
                $rmq = rmq_connect($connectedEvent);
            }
        }
    );
    return $rmq;
}

sub rmq_connect($) {
    my $connectedEvent = shift;

    return AnyEvent::RabbitMQ->new->load_xml_spec()->connect(
        host       => $host,
        port       => $port,
        user       => $user,
        pass       => $pass,
        vhost      => '/',
        timeout    => 1,
        tune       => { heartbeat => 30},
        nodelay    => 1, # Reduces latency by disabling Nagle's algorithm
        on_success => sub {
            my $rmq_connection = shift;
            $rmq_connection->open_channel(
                on_success => sub {
                    $rmq_channel = shift;
                    $rmq_channel->confirm(),
                        $rmq_channel->declare_exchange(
                            exchange   => $exchange_name,
                            on_success => sub {
                                logwi("$log_prefix: declared exchange $exchange_name");
                                foreach my $qname (keys %$queues) {
                                    $connectedEvent->begin;
                                    create_queue($qname, $qname, $connectedEvent);
                                }
                            },
                            on_failure => sub {
                                logwe("$log_prefix: exchange declare failed")
                            },
                        );
                },
                on_failure => sub {
                    logwe("$log_prefix: channel opening failed")
                },
                on_close   => sub {
                    my $method_frame = shift->method_frame;
                    $rmq_channel = undef;
                    logwe("$log_prefix: channel was closed: ".$method_frame->reply_code.", ".$method_frame->reply_text);
                },
            );
        },
        on_failure => sub {
            logwe("$log_prefix: connection was failed");
        },
        on_read_failure => sub {
            logwe("$log_prefix: read was failed");
        },
        on_return  => sub {
            my $frame = shift;
            logwe("$log_prefix: unable to deliver: " . Dumper($frame));
        },
        on_close   => sub {
            $rmq_channel = undef;
            my $why = shift;
            if (ref($why)) {
                my $method_frame = $why->method_frame;
                logwe("$log_prefix: connection was closed:" .$method_frame->reply_code.", ".$method_frame->reply_text);
            }
            else {
                logwe("$log_prefix: connection was closed: $why");
            }
        },
    )
}

sub create_queue {
    my $queue_name = shift;
    my $routing_key = shift;
    my $connectedEvent = shift;

    $rmq_channel->declare_queue(
        exchange    => $exchange_name,
        queue       => $queue_name,
        durable     => 1,
        auto_delete => 0,
        passive     => 0,
        on_success  => sub {
            logwi("Created rmq queue $queue_name");
            $rmq_channel->bind_queue(
                exchange    => $exchange_name,
                queue       => $queue_name,
                routing_key => $routing_key,
                on_success  => sub {
                    logwi("$log_prefix: queue $queue_name is bind to routing key $routing_key");
                    $queues->{$queue_name}->{ok} = 1;
                    $connectedEvent->end;
                },
                on_failure  => sub {
                    logwe("$log_prefix: unable to bind queue $queue_name");
                    $queues->{$queue_name}->{ok} = 0;
                },
            )
        },
        on_failure  => sub {
            logwe("$log_prefix: unable to create queue $queue_name");
            $queues->{$queue_name}->{ok} = 0;
        },
    )
}

sub publish {
    my $routing_key = shift;
    my $data = shift;
    my $json = new JSON::XS;
    my $id = createNewMessageID();
    $rmq_channel->publish(
        exchange    => $exchange_name,
        routing_key => $routing_key,
        body        => $json->encode($data),
        header      => {
            message_id => $id
        },
        mandatory   => 1,
        on_return  => sub {
            logwe("$log_prefix: can't send the message with key $routing_key");
        },
    );
    return $id;
}

sub createNewMessageID {
    return join("", @id_chars[ map {rand @id_chars} (1..10)]);
}

sub isConnected() {
    return (defined $rmq_channel)
}
1;