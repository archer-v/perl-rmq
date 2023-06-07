#!/usr/bin/perl
#
# lightweight logging module
# (c) Starshiptroopers, Aleksander Cherviakov

package logtiny;
# It is a tiny log module without dependencies (replacement for standard log module)
use Exporter;

@ISA = ("Exporter");
@EXPORT = qw(&logwi &logww &logwe &logwn &logwp &log_init &logdump &logns &logSetTimestampPlaceholderMode
			  &timestamp &logSetConsoleMode &logc &getRecentError);
use utf8;

use Cwd qw (realpath);
BEGIN {
  unless (eval "require \"log.conf\"; 1") { }
}

=pod

logwi, logww, logwe, logwn - functions for logging with severities: info, warning, error, notice
logwp - functions to inform about progress of long time process. It used by web client
=cut

my $UTF = 0;
my $CONSOLE = 0;
my $LOG_FILENAME = undef;
my $LOG_APP = '';
#дополнительный идентификатор объекта или сущности к которой будут относится последующий сообщения, выводится в журналах перед сообщением
my $LOG_NAMESPACE = undef; 
#ссылка на идентификатор процесса, или номер запроса (для веб-приложений), выводится в логах []
my $TID = undef; 
my $TIMESTAMP_PLACEHOLDER = 0;

my $recentErrorMessage = '';
#it needs to remove previous console line for repeating progress messages (to show beautiful)
my $lastLevel = '';
my $currentLevel = '';
my $lastMessageLength = 0;

sub logw  {
  my $app = shift;
  my $log = shift;
  my $txt = shift;
  my $level = shift;
  
  my $timestamp = timestamp();
  
  if (! defined $level) {
    $level = 'info';
  }
  $currentLevel = $level;
  my $header = "$timestamp ".((defined $TID)?"[$$][$$TID] ":'').uc($level).": ".(($app ne '')?'['.$app.'] ':'').((defined $LOG_NAMESPACE)?'['.$LOG_NAMESPACE.'] ':'');
  if ($TIMESTAMP_PLACEHOLDER) {
    my $l = length($header);
    $header='';
    for(my $i = 0; $i < $l; $i++) {$header .= ' ';};
  }
  my $message = $header.$txt;
  
  if (defined $log) {
    open(DEBUG, ">>$log") or die 'Can not open file ('.$log.') for logging';
    binmode DEBUG, ':utf8' if ($UTF);
    print DEBUG "$message\n";
    close(DEBUG);    
  }
  $lastLevel = $currentLevel;
  $lastMessageLength = length($message);
  
  print $message."\n" if ($CONSOLE || (! defined $log));
}

sub logwi($) {
  logw($LOG_APP, $LOG_FILENAME, shift, 'info');
}

sub logww($) {
  logw($LOG_APP, $LOG_FILENAME, shift, 'warn');
  return 1;
}

sub logwe($) {
  $recentErrorMessage = shift;
  logw($LOG_APP, $LOG_FILENAME, $recentErrorMessage, 'error');
  return 1;
}

sub logwn($) {
  logw($LOG_APP, $LOG_FILENAME, shift, 'notice');
  return 1;
}

sub logwp($) {
  logw($LOG_APP, $LOG_FILENAME, shift, 'progress');
  return 1;
}

#вывести обязательно в консоль
sub logc($) {
  my $c = $CONSOLE;
  $CONSOLE = 1;
  logw($LOG_APP, $LOG_FILENAME, shift, 'notice');
  $CONSOLE = $c;
}

sub logdump($)
{
  my $txt = shift;
  
  return if (!defined $LOG_FILENAME);
  
  open(DEBUG, ">>$LOG_FILENAME");
  binmode DEBUG, ':utf8' if ($UTF);
  print DEBUG '=====BEGIN DUMP====='."\n$txt\n".'=====END DUMP======='."\n";
  print '=====BEGIN DUMP====='."\n$txt\n".'=====END DUMP======='."\n" if ($CONSOLE);
  close(DEBUG);
}

#остановлено для совместимости со старым кодом
sub setUTFmode() {
	$UTF = 1;
}

#остановлено для совместимости со старым кодом
sub setConsoleMode {
	my $mode = shift;
	$CONSOLE = (defined $mode)?$mode:1;
}

#для красивого вывода многострочного сообщения, чтобы второе сообщение выводилось со сдвигом на размер начального timestamp
sub logSetTimestampPlaceholderMode {
	$TIMESTAMP_PLACEHOLDER = shift;
}

#дополнительный идентификатор объекта или сущности к которой будут относится последующий сообщения, выводится в журналах перед сообщением
sub logns {
	$LOG_NAMESPACE = shift;
	$LOG_NAMESPACE = undef if ($LOG_NAMESPACE eq '');
}

sub logSetConsoleMode {
    setConsoleMode(shift);
}

sub log_init {
  my %cnf = @_;
  return if (defined $LOG_FILENAME);

  for (keys %cnf) {
    $CONSOLE = $cnf{$_} if ($_ eq 'consolemode');
    $UTF = $cnf{$_} if ($_ eq 'utfmode');
    if ($_ eq 'filename') {
      if (! -e $cnf{$_}) {
        open(LD, ">>$cnf{$_}") or die 'Can not open file ('.$cnf{$_}.') for logging';
        close(LD);
      }
      $LOG_FILENAME = realpath($cnf{$_})
    }
    $LOG_APP = $cnf{$_} if ($_ eq 'application');
  }
}

sub getLogFilename {
	return $LOG_FILENAME;
}

sub getRecentError {
	return $recentErrorMessage;
}

sub timestamp {
  my $time = shift;
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime((defined $time)?$time:time);
  return sprintf('%4d-%02d-%02d %02d:%02d:%02d' , $year+1900,$mon+1,$mday,$hour,$min,$sec);    
}


END {
}
1;
