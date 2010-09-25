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





sub mirror_file {
    my ($self,$path,$remote_file,$local_mirror_path) = @_;

    my $release    = $self->release;
    my $release_id = $self->release_id;

    my $contact_email = $self->contact_email;
    my $ftp_server    = $self->remote_ftp_server;

    $self->logit->info("  mirroring $path/$remote_file from $ftp_server to $local_mirror_path");

    my $cwd = getcwd();
    chdir $local_mirror_path or $self->logit->warn("cannot chdir to local mirror directory: $local_mirror_path");

    my $ftp = Net::FTP->new($ftp_server, Debug => 0, Passive => 1) or $self->logit->logdie("cannot construct Net::FTP object");
    $ftp->login('anonymous', $contact_email) or $self->logit->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->logit->warn("couldn't switch to binary mode for FTP");
    $ftp->cwd($path)                         or $self->logit->error("cannot chdir to remote dir ($path)");
    $ftp->get($remote_file)                  or $self->logit->error("cannot fetch to $remote_file");
    $ftp->quit;
    $self->logit->info("  mirroring $path/$remote_file: complete");
}












1;
