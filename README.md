# perl-rmq
RabbitMQ communication wrapping module and some examples that uses AnyEvent::RabbitMQ for interacting with RabbitMQ 

usage:
* clone repo
* setup required perl modules (AnyEvent::RabbitMQ, etc) by cpan utility or linux package manager. In order to see missing modules just run ./rmq-producer-example.pl 
* start rabbitMQ server `docker-compose up`
* start `./rmq-producer-example.pl` to post message to the rabbitMQ
* start `./rmq-consumer-example.pl` to read this message from rabbitMQ queue
