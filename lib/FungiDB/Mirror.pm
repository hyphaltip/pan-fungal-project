package Mirror;

use Moose;
use Net::FTP;
extends qw/FungiDB/;


sub mirror_directory {
    my $self = shift;
    my $cwd = getcwd();
    $self->logit->info("  mirroring directory $path from $ftp_server to $local_mirror_path");
    chdir $local_mirror_path or $self->logit->logdie("cannot chdir to local mirror directory: $local_mirror_path\
");

    my $ftp = Net::FTP::Recursive->new($ftp_server, Debug => 0, Passive => 1) or $self->logit->logdie("can't ins\
tantiate Net::FTP object");
    $ftp->login('anonymous', $contact_email) or $self->logit->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->logit->warn("couldn't switch to binary mode for FTP");
    $ftp->cwd($path)                         or $self->logit->error("cannot chdir to remote dir ($path)") && ret\
	urn;
    my $r = $ftp->rget();
    $ftp->quit;
    $self->logit->info("  mirroring directory: complete");
   
}

















1;
